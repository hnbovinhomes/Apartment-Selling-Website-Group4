package com.apartment.website.common.filter;

import com.apartment.website.config.AppContextListener;
import com.apartment.website.notification.service.NotificationService;
import com.apartment.website.user.entity.User;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Chạy trước mọi request (trừ file tĩnh css/ảnh):
 *  1. Lấy người dùng đã đăng nhập trong session -> đặt request attribute "currentUser" cho header.jsp đọc.
 *  2. Đếm thông báo chưa đọc -> "unreadCount" (số đỏ trên cái chuông).
 *  3. Trang cần đăng nhập (/viewings, /notifications, /postings) mà chưa đăng nhập -> chuyển tới trang đăng nhập.
 */
public class AuthFilter implements Filter {
    /** Tên attribute lưu User trong session. */
    public static final String SESSION_USER = "loginUser";

    private static final String[] STATIC_PREFIXES = {"/css/", "/images/", "/js/"};
    private static final String[] PROTECTED_PATHS = {"/viewings", "/notifications", "/postings"};

    private NotificationService notificationService;

    @Override
    public void init(FilterConfig config) {
        notificationService = (NotificationService) config.getServletContext()
                .getAttribute(AppContextListener.NOTIFICATION_SERVICE);
    }

    @Override
    public void doFilter(ServletRequest req, ServletResponse resp, FilterChain chain) throws IOException, ServletException {
        HttpServletRequest request = (HttpServletRequest) req;
        HttpServletResponse response = (HttpServletResponse) resp;
        String path = request.getServletPath();

        // file tĩnh: không cần biết ai đang đăng nhập
        if (startsWithAny(path, STATIC_PREFIXES)) {
            chain.doFilter(request, response);
            return;
        }

        User user = getLoginUser(request);
        if (user != null) {
            request.setAttribute("currentUser", user);
            request.setAttribute("unreadCount", notificationService.unreadCount(user.getUserId()));
        }

        if (user == null && startsWithAny(path, PROTECTED_PATHS)) {
            // nhớ trang đang muốn vào, đăng nhập xong quay lại đúng trang đó
            String next = path;
            if (request.getQueryString() != null) {
                next = next + "?" + request.getQueryString();
            }
            String loginUrl = request.getContextPath() + "/auth?action=login&next="
                    + URLEncoder.encode(next, StandardCharsets.UTF_8);
            response.sendRedirect(loginUrl);
            return;
        }

        chain.doFilter(request, response);
    }

    /** Người dùng đang đăng nhập, chưa đăng nhập thì null. Không tạo session mới. */
    public static User getLoginUser(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null) {
            return null;
        }
        return (User) session.getAttribute(SESSION_USER);
    }

    private static boolean startsWithAny(String path, String[] prefixes) {
        for (int i = 0; i < prefixes.length; i++) {
            if (path.startsWith(prefixes[i])) {
                return true;
            }
        }
        return false;
    }
}
