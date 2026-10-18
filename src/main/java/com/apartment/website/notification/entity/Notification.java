package com.apartment.website.notification.entity;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Thông báo hiện ở cái chuông 🔔 (bảng notifications).
 * related_type + related_id cho biết thông báo nói về cái gì, vd related_type = 'VIEWING', related_id = viewing_id.
 */
public class Notification {
    public static final String TYPE_VIEWING = "VIEWING";
    public static final String RELATED_VIEWING = "VIEWING";

    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy");

    private long notificationId;
    private long userId;
    private String title;
    private String message;
    private String notificationType;
    private String relatedType;
    private Long relatedId;
    private boolean read;
    private LocalDateTime createdAt;
    private LocalDateTime readAt;

    public Notification() {
    }

    public long getNotificationId() {
        return notificationId;
    }

    public void setNotificationId(long notificationId) {
        this.notificationId = notificationId;
    }

    public long getUserId() {
        return userId;
    }

    public void setUserId(long userId) {
        this.userId = userId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getNotificationType() {
        return notificationType;
    }

    public void setNotificationType(String notificationType) {
        this.notificationType = notificationType;
    }

    public String getRelatedType() {
        return relatedType;
    }

    public void setRelatedType(String relatedType) {
        this.relatedType = relatedType;
    }

    public Long getRelatedId() {
        return relatedId;
    }

    public void setRelatedId(Long relatedId) {
        this.relatedId = relatedId;
    }

    /** Cột is_read. JSP: ${n.read} */
    public boolean isRead() {
        return read;
    }

    public void setRead(boolean read) {
        this.read = read;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getReadAt() {
        return readAt;
    }

    public void setReadAt(LocalDateTime readAt) {
        this.readAt = readAt;
    }

    /** JSP: ${n.timeText} -> "09:15 14/10/2026" */
    public String getTimeText() {
        if (createdAt == null) {
            return "";
        }
        return createdAt.format(TIME_FORMAT);
    }
}
