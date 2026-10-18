package com.apartment.website.notification.repository;

import com.apartment.website.notification.entity.Notification;

import java.util.List;

public interface NotificationRepository {
    /** Tạo thông báo mới (chưa đọc) cho 1 người dùng. */
    void create(Notification notification);

    /** Thông báo của 1 người, mới nhất trước. */
    List<Notification> findByUser(long userId, int limit);

    /** Số thông báo chưa đọc (số đỏ trên cái chuông). */
    int countUnread(long userId);

    /** Đánh dấu đã đọc 1 thông báo (chỉ khi đúng chủ của nó). Trả về thông báo đó, không có thì null. */
    Notification markRead(long notificationId, long userId);

    /** Đánh dấu đã đọc tất cả. */
    void markAllRead(long userId);
}
