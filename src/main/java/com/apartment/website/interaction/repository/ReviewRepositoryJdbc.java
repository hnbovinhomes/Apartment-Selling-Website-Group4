package com.apartment.website.interaction.repository;

import com.apartment.website.config.Database;
import com.apartment.website.interaction.entity.Review;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Lưu đánh giá trong PostgreSQL (bảng reviews, JOIN users để lấy tên người đánh giá). */
public class ReviewRepositoryJdbc implements ReviewRepository {

    @Override
    public List<Review> findByProperty(long propertyId) {
        String sql = "SELECT r.review_id, r.customer_id, r.property_id, r.rating, r.comment, r.status, "
                + "r.created_at, r.updated_at, u.full_name "
                + "FROM reviews r "
                + "JOIN users u ON u.user_id = r.customer_id "
                + "WHERE r.property_id = ? AND r.status = 'VISIBLE' "
                + "ORDER BY r.updated_at DESC, r.review_id DESC";

        List<Review> reviews = new ArrayList<Review>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, propertyId);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        Review review = new Review();
                        review.setReviewId(rs.getLong("review_id"));
                        review.setCustomerId(rs.getLong("customer_id"));
                        review.setPropertyId(rs.getLong("property_id"));
                        review.setRating(rs.getInt("rating"));
                        review.setComment(rs.getString("comment"));
                        review.setStatus(rs.getString("status"));
                        review.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
                        review.setUpdatedAt(rs.getObject("updated_at", LocalDateTime.class));
                        review.setReviewerName(rs.getString("full_name"));
                        reviews.add(review);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return reviews;
    }

    @Override
    public boolean save(long customerId, long propertyId, int rating, String comment) {
        // UNIQUE (customer_id, property_id) -> gửi lại thì UPDATE.
        // xmax = 0 nghĩa là dòng vừa được INSERT (không phải UPDATE).
        String sql = "INSERT INTO reviews (customer_id, property_id, rating, comment) "
                + "VALUES (?, ?, ?, ?) "
                + "ON CONFLICT (customer_id, property_id) DO UPDATE "
                + "SET rating = EXCLUDED.rating, "
                + "comment = EXCLUDED.comment, "
                + "updated_at = CURRENT_TIMESTAMP "
                + "RETURNING (xmax = 0) AS inserted";

        boolean inserted = false;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, customerId);
                statement.setLong(2, propertyId);
                statement.setInt(3, rating);
                statement.setString(4, comment);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        inserted = rs.getBoolean("inserted");
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return inserted;
    }
}
