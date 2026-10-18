package com.apartment.website.common.controller;

import com.apartment.website.config.Database;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/** TẠM THỜI - mở /db-check để kiểm tra kết nối PostgreSQL. Kiểm tra xong thì XÓA file này. */
public class DbCheckServlet extends HttpServlet {
    private static final String[] TABLES = {
            "users", "customers", "owners", "buildings", "apartments", "properties",
            "property_images", "listings", "favorites", "reviews", "notifications",
            "property_viewings", "property_reports", "report_actions", "admin_activity_logs"
    };

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        response.setContentType("text/plain;charset=UTF-8");
        PrintWriter out = response.getWriter();
        out.println("db.url    = " + Database.get("db.url", "(chua cau hinh)"));
        out.println("db.user   = " + Database.get("db.user", ""));
        out.println();

        try (Connection connection = Database.getConnection()) {
            String productName = connection.getMetaData().getDatabaseProductName();
            String productVersion = connection.getMetaData().getDatabaseProductVersion();
            out.println("KET NOI THANH CONG: " + productName + " " + productVersion);
            out.println();

            for (int i = 0; i < TABLES.length; i++) {
                String table = TABLES[i];
                // tên bảng lấy từ mảng hằng ở trên (không phải dữ liệu người dùng) nên ghép chuỗi được
                String sql = "SELECT COUNT(*) FROM " + table;
                try (PreparedStatement statement = connection.prepareStatement(sql)) {
                    try (ResultSet rs = statement.executeQuery()) {
                        if (rs.next()) {
                            out.printf("%-18s %d dong%n", table, rs.getLong(1));
                        }
                    }
                } catch (SQLException e) {
                    out.printf("%-18s LOI: %s%n", table, e.getMessage());
                }
            }

            String countSql = "SELECT COUNT(*) FILTER (WHERE listing_type = 'SALE'), "
                    + "COUNT(*) FILTER (WHERE listing_type = 'RENT') "
                    + "FROM properties "
                    + "WHERE status = 'AVAILABLE'";
            try (PreparedStatement statement = connection.prepareStatement(countSql)) {
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        out.println();
                        out.println("Can ho BAN AVAILABLE (tab mac dinh): " + rs.getLong(1));
                        out.println("Can ho THUE AVAILABLE (?type=RENT): " + rs.getLong(2));
                    }
                }
            } catch (SQLException ignored) {
                // bảng properties chưa có cột listing_type -> bỏ qua phần này
            }
        } catch (SQLException e) {
            out.println("KET NOI THAT BAI: " + e.getMessage());
            Throwable cause = e.getCause();
            if (cause != null) {
                out.println("Nguyen nhan: " + cause);
            }
        }
    }
}
