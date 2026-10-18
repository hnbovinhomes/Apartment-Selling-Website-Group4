package com.apartment.website.notification.service;

import com.apartment.website.notification.entity.Notification;
import com.apartment.website.notification.repository.NotificationRepository;

import java.util.List;

/** Gửi / đọc thông báo ở cái chuông. */
public class NotificationService {
    // trang thông báo hiện tối đa 50 cái mới nhất
    public static final int PAGE_LIMIT = 50;

    private final NotificationRepository repository;

    public NotificationService(NotificationRepository repository) {
        this.repository = repository;
    }

    /** Gửi thông báo về 1 lịch hẹn cho người dùng userId. */
    public void notifyViewing(long userId, String title, String message, long viewingId) {
        Notification notification = new Notification();
        notification.setUserId(userId);
        notification.setTitle(title);
        notification.setMessage(message);
        notification.setNotificationType(Notification.TYPE_VIEWING);
        notification.setRelatedType(Notification.RELATED_VIEWING);
        notification.setRelatedId(viewingId);
        repository.create(notification);
    }

    public List<Notification> list(long userId) {
        return repository.findByUser(userId, PAGE_LIMIT);
    }

    public int unreadCount(long userId) {
        return repository.countUnread(userId);
    }

    /** Trả về thông báo vừa đánh dấu đã đọc, không phải của người này thì null. */
    public Notification markRead(long notificationId, long userId) {
        return repository.markRead(notificationId, userId);
    }

    public void markAllRead(long userId) {
        repository.markAllRead(userId);
    }
}
