package com.apartment.website.notification.controller;

import com.apartment.website.common.filter.AuthFilter;
import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.notification.entity.Notification;
import com.apartment.website.notification.service.NotificationService;
import com.apartment.website.user.entity.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

/**
 * Cái chuông 🔔 (cần đăng nhập, AuthFilter đã kiểm tra):
 *  GET  /notifications                      -> danh sách thông báo -> views/notification/list.jsp
 *  POST /notifications  (action=read, id)   -> đánh dấu đã đọc, mở lịch hẹn liên quan
 *  POST /notifications  (action=readAll)    -> đánh dấu đã đọc tất cả
 */
public class NotificationServlet extends HttpServlet {
    private NotificationService notificationService;

    @Override
    public void init() {
        notificationService = (NotificationService) getServletContext().getAttribute(AppContextListener.NOTIFICATION_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        User user = AuthFilter.getLoginUser(request);
        List<Notification> notifications = notificationService.list(user.getUserId());

        request.setAttribute("active", "notifications");
        request.setAttribute("notifications", notifications);
        View.forward(request, response, "notification/list");
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        User user = AuthFilter.getLoginUser(request);
        String action = request.getParameter("action");

        if ("readAll".equals(action)) {
            notificationService.markAllRead(user.getUserId());
            response.sendRedirect(request.getContextPath() + "/notifications");
            return;
        }

        if ("read".equals(action)) {
            Long id = toLong(request.getParameter("id"));
            Notification notification = null;
            if (id != null) {
                notification = notificationService.markRead(id, user.getUserId());
            }
            // thông báo về lịch hẹn -> mở trang Lịch hẹn, cuộn tới đúng lịch đó
            if (notification != null
                    && Notification.RELATED_VIEWING.equals(notification.getRelatedType())
                    && notification.getRelatedId() != null) {
                response.sendRedirect(request.getContextPath() + "/viewings#v" + notification.getRelatedId());
                return;
            }
            response.sendRedirect(request.getContextPath() + "/notifications");
            return;
        }

        response.sendError(HttpServletResponse.SC_NOT_FOUND);
    }

    private static Long toLong(String text) {
        if (text == null) {
            return null;
        }
        try {
            return Long.parseLong(text.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
