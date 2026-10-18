package com.apartment.website.user.repository;

import com.apartment.website.config.Database;
import com.apartment.website.user.entity.Admin;
import com.apartment.website.user.entity.Customer;
import com.apartment.website.user.entity.Owner;
import com.apartment.website.user.entity.User;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;

/** Đọc / ghi tài khoản trong PostgreSQL (bảng users, customers, owners). */
public class UserRepositoryJdbc implements UserRepository {

    @Override
    public User findByPhoneOrEmail(String phoneOrEmail) {
        // LEFT JOIN owners để lấy thêm tax_code, identity_verified nếu là chủ căn hộ
        String sql = "SELECT u.user_id, u.username, u.email, u.password_hash, u.role, u.created_at, u.is_active, "
                + "u.full_name, u.phone, u.cccd, u.updated_at, u.last_login_at, u.blocked_reason, u.blocked_at, "
                + "u.blocked_by, o.tax_code, o.identity_verified "
                + "FROM users u "
                + "LEFT JOIN owners o ON o.owner_id = u.user_id "
                + "WHERE u.phone = ? OR LOWER(TRIM(u.email)) = LOWER(TRIM(?))";

        User user = null;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setString(1, phoneOrEmail);
                statement.setString(2, phoneOrEmail);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        user = mapUser(rs);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return user;
    }

    @Override
    public boolean existsByPhone(String phone) {
        String sql = "SELECT 1 FROM users WHERE phone = ?";
        return exists(sql, phone);
    }

    @Override
    public boolean existsByEmail(String email) {
        // giống unique index uq_users_email_normalized: không phân biệt hoa thường, bỏ khoảng trắng 2 đầu
        String sql = "SELECT 1 FROM users WHERE LOWER(TRIM(email)) = LOWER(TRIM(?))";
        return exists(sql, email);
    }

    @Override
    public boolean existsByCccd(String cccd) {
        String sql = "SELECT 1 FROM users WHERE cccd = ?";
        return exists(sql, cccd);
    }

    /** Chạy câu SELECT có 1 tham số, có ít nhất 1 dòng kết quả thì trả về true. */
    private static boolean exists(String sql, String value) {
        boolean found = false;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setString(1, value);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        found = true;
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return found;
    }

    @Override
    public long create(User user) {
        // username = phone vì DB có CHECK chk_username_equals_phone
        String insertUserSql = "INSERT INTO users (username, email, password_hash, role, full_name, phone, cccd) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?) "
                + "RETURNING user_id";
        String insertCustomerSql = "INSERT INTO customers (customer_id) VALUES (?)";
        String insertOwnerSql = "INSERT INTO owners (owner_id) VALUES (?)";

        try (Connection connection = Database.getConnection()) {
            // users + customers/owners cùng 1 transaction: lỗi giữa chừng thì không còn tài khoản "nửa vời"
            connection.setAutoCommit(false);

            long userId = 0;
            try (PreparedStatement statement = connection.prepareStatement(insertUserSql)) {
                statement.setString(1, user.getPhone());
                statement.setString(2, user.getEmail());
                statement.setString(3, user.getPasswordHash());
                statement.setString(4, user.getRole());
                statement.setString(5, user.getFullName());
                statement.setString(6, user.getPhone());
                statement.setString(7, user.getCccd());
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        userId = rs.getLong("user_id");
                    }
                }
            }

            String roleSql;
            if (User.ROLE_OWNER.equals(user.getRole())) {
                roleSql = insertOwnerSql;
            } else {
                roleSql = insertCustomerSql;
            }
            try (PreparedStatement statement = connection.prepareStatement(roleSql)) {
                statement.setLong(1, userId);
                statement.executeUpdate();
            }

            connection.commit();
            return userId;
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void updateLastLogin(long userId) {
        String sql = "UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE user_id = ?";
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, userId);
                statement.executeUpdate();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    /** Đọc 1 dòng thành Customer / Owner / Admin tùy cột role. */
    private static User mapUser(ResultSet rs) throws SQLException {
        String role = rs.getString("role");

        User user;
        if (User.ROLE_OWNER.equals(role)) {
            Owner owner = new Owner();
            owner.setTaxCode(rs.getString("tax_code"));
            owner.setIdentityVerified(rs.getBoolean("identity_verified"));
            user = owner;
        } else if (User.ROLE_ADMIN.equals(role)) {
            user = new Admin();
        } else {
            user = new Customer();
        }

        user.setUserId(rs.getLong("user_id"));
        user.setUsername(rs.getString("username"));
        user.setEmail(rs.getString("email"));
        user.setPasswordHash(rs.getString("password_hash"));
        user.setRole(role);
        user.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
        user.setActive(rs.getInt("is_active") == 1);
        user.setFullName(rs.getString("full_name"));
        user.setPhone(rs.getString("phone"));
        user.setCccd(rs.getString("cccd"));
        user.setUpdatedAt(rs.getObject("updated_at", LocalDateTime.class));
        user.setLastLoginAt(rs.getObject("last_login_at", LocalDateTime.class));
        user.setBlockedReason(rs.getString("blocked_reason"));
        user.setBlockedAt(rs.getObject("blocked_at", LocalDateTime.class));
        long blockedBy = rs.getLong("blocked_by");
        if (rs.wasNull()) {
            user.setBlockedBy(null);
        } else {
            user.setBlockedBy(blockedBy);
        }
        return user;
    }
}
