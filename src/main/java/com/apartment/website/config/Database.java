package com.apartment.website.config;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

/**
 * Đọc app.properties (ưu tiên biến môi trường, vd db.url -> DB_URL) và cung cấp kết nối PostgreSQL
 * qua một connection pool tự viết: dùng xong gọi close() là trả lại pool chứ không đóng thật.
 */
public final class Database {
    // không vượt quá max_connections của PostgreSQL
    private static final int POOL_SIZE = 8;
    private static final int WAIT_SECONDS = 5;
    private static final Properties CONFIG = new Properties();
    private static final BlockingQueue<Connection> IDLE = new LinkedBlockingQueue<Connection>();
    private static int created = 0;
    private static boolean driverLoaded = false;

    static {
        try (InputStream in = Database.class.getResourceAsStream("/app.properties")) {
            if (in != null) {
                CONFIG.load(new InputStreamReader(in, StandardCharsets.UTF_8));
            }
        } catch (IOException e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    private Database() {
    }

    public static String get(String key, String defaultValue) {
        String envName = key.toUpperCase().replace('.', '_');
        String value = System.getenv(envName);
        if (value == null) {
            value = CONFIG.getProperty(key, defaultValue);
        }
        return value.trim();
    }

    /** Mở 1 kết nối thật tới PostgreSQL. */
    private static Connection open() throws SQLException {
        // Tomcat: cần nạp driver thủ công để DriverManager thấy driver trong WEB-INF/lib
        if (!driverLoaded) {
            try {
                Class.forName("org.postgresql.Driver");
                driverLoaded = true;
            } catch (ClassNotFoundException e) {
                throw new SQLException("Thiếu driver PostgreSQL (postgresql.jar)", e);
            }
        }
        String url = get("db.url", "");
        String user = get("db.user", "");
        String password = get("db.password", "");
        return DriverManager.getConnection(url, user, password);
    }

    /** Mượn 1 kết nối. LUÔN dùng try-with-resources để tự động trả lại. */
    public static Connection getConnection() throws SQLException {
        // 1. Lấy kết nối đang rảnh trong pool
        Connection real = IDLE.poll();

        // 2. Pool chưa đủ POOL_SIZE kết nối -> mở thêm kết nối mới
        if (real == null) {
            synchronized (Database.class) {
                if (created < POOL_SIZE) {
                    real = open();
                    created++;
                }
            }
        }

        // 3. Pool đầy -> chờ người khác trả kết nối
        if (real == null) {
            try {
                real = IDLE.poll(WAIT_SECONDS, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                throw new SQLException(e);
            }
            if (real == null) {
                throw new SQLException("Hết kết nối trong pool");
            }
        }

        // 4. Kết nối đã chết -> mở cái mới thay
        if (real.isClosed() || !real.isValid(2)) {
            real = open();
        }

        // 5. Bọc kết nối lại: gọi close() sẽ trả về pool thay vì đóng thật
        PooledConnectionHandler handler = new PooledConnectionHandler(real);
        Class<?>[] interfaces = new Class<?>[] { Connection.class };
        Object wrapped = Proxy.newProxyInstance(Connection.class.getClassLoader(), interfaces, handler);
        return (Connection) wrapped;
    }

    /** Gọi khi Tomcat tắt ứng dụng. */
    public static void shutdown() {
        Connection connection = IDLE.poll();
        while (connection != null) {
            try {
                connection.close();
            } catch (SQLException ignored) {
                // đang tắt ứng dụng, bỏ qua lỗi
            }
            connection = IDLE.poll();
        }
    }

    /**
     * Mọi lời gọi tới Connection đều đi qua invoke():
     * - close() -> trả kết nối thật về pool
     * - các hàm khác (prepareStatement, commit...) -> chuyển thẳng cho kết nối thật
     */
    private static class PooledConnectionHandler implements InvocationHandler {
        private final Connection real;
        private boolean returned = false;

        PooledConnectionHandler(Connection real) {
            this.real = real;
        }

        @Override
        public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
            if (method.getName().equals("close")) {
                if (!returned) {
                    returned = true;
                    // transaction chưa commit -> hủy để kết nối sạch cho người dùng sau
                    if (!real.getAutoCommit()) {
                        real.rollback();
                        real.setAutoCommit(true);
                    }
                    IDLE.offer(real);
                }
                return null;
            }
            try {
                return method.invoke(real, args);
            } catch (InvocationTargetException e) {
                throw e.getCause();
            }
        }
    }
}
