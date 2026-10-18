package com.apartment.website.notification.repository;

import com.apartment.website.config.Database;
import com.apartment.website.notification.entity.Notification;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Thông báo trong PostgreSQL (bảng notifications). */
public class NotificationRepositoryJdbc implements NotificationRepository {

    private static final String COLUMNS = "notification_id, user_id, title, message, notification_type, "
            + "related_type, related_id, is_read, created_at, read_at ";

    @Override
    public void create(Notification notification) {
        String sql = "INSERT INTO notifications (user_id, title, message, notification_type, related_type, related_id) "
                + "VALUES (?, ?, ?, ?, ?, ?)";

        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, notification.getUserId());
                statement.setString(2, notification.getTitle());
                statement.setString(3, notification.getMessage());
                statement.setString(4, notification.getNotificationType());
                statement.setString(5, notification.getRelatedType());
                statement.setObject(6, notification.getRelatedId());
                statement.executeUpdate();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public List<Notification> findByUser(long userId, int limit) {
        String sql = "SELECT " + COLUMNS
                + "FROM notifications "
                + "WHERE user_id = ? "
                + "ORDER BY created_at DESC, notification_id DESC "
                + "LIMIT ?";

        List<Notification> notifications = new ArrayList<Notification>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, userId);
                statement.setInt(2, limit);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        notifications.add(mapNotification(rs));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return notifications;
    }

    @Override
    public int countUnread(long userId) {
        String sql = "SELECT COUNT(*) AS unread "
                + "FROM notifications "
                + "WHERE user_id = ? AND is_read = false";

        int count = 0;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, userId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        count = rs.getInt("unread");
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return count;
    }

    @Override
    public Notification markRead(long notificationId, long userId) {
        // COALESCE: đã đọc rồi thì giữ nguyên read_at cũ. CHECK ck_notification_read_at: có read_at thì is_read phải true
        String sql = "UPDATE notifications "
                + "SET is_read = true, read_at = COALESCE(read_at, CURRENT_TIMESTAMP) "
                + "WHERE notification_id = ? AND user_id = ? "
                + "RETURNING " + COLUMNS;

        Notification notification = null;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, notificationId);
                statement.setLong(2, userId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        notification = mapNotification(rs);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return notification;
    }

    @Override
    public void markAllRead(long userId) {
        String sql = "UPDATE notifications "
                + "SET is_read = true, read_at = CURRENT_TIMESTAMP "
                + "WHERE user_id = ? AND is_read = false";

        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, userId);
                statement.executeUpdate();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    private static Notification mapNotification(ResultSet rs) throws SQLException {
        Notification notification = new Notification();
        notification.setNotificationId(rs.getLong("notification_id"));
        notification.setUserId(rs.getLong("user_id"));
        notification.setTitle(rs.getString("title"));
        notification.setMessage(rs.getString("message"));
        notification.setNotificationType(rs.getString("notification_type"));
        notification.setRelatedType(rs.getString("related_type"));
        long relatedId = rs.getLong("related_id");
        if (rs.wasNull()) {
            notification.setRelatedId(null);
        } else {
            notification.setRelatedId(relatedId);
        }
        notification.setRead(rs.getBoolean("is_read"));
        notification.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
        notification.setReadAt(rs.getObject("read_at", LocalDateTime.class));
        return notification;
    }
}
