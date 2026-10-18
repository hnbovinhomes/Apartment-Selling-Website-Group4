package com.apartment.website.user.controller;

import com.apartment.website.common.exception.AuthException;
import com.apartment.website.common.filter.AuthFilter;
import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.user.dto.RegisterRequest;
import com.apartment.website.user.entity.User;
import com.apartment.website.user.service.AuthService;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

/**
 * Điều hướng bằng tham số action (URL /auth khai báo trong web.xml):
 *  GET  /auth?action=login               -> form đăng nhập        -> views/auth/login.jsp
 *  GET  /auth?action=register&role=OWNER -> form đăng ký          -> views/auth/register.jsp
 *  GET  /auth?action=logout              -> đăng xuất, về trang chủ
 *  POST /auth  (action=login | register) -> kiểm tra, lưu User vào session, chuyển về trang trước đó (?next=)
 * Trạng thái đăng nhập lưu bằng Session ("loginUser"); ô "Ghi nhớ" lưu SĐT/email bằng Cookie "rememberPhone".
 */
public class AuthServlet extends HttpServlet {
    // tên cookie ghi nhớ SĐT / email ở trang đăng nhập
    public static final String REMEMBER_COOKIE = "rememberPhone";
    // 30 ngày tính bằng giây
    private static final int REMEMBER_SECONDS = 30 * 24 * 60 * 60;

    private AuthService authService;

    @Override
    public void init() {
        authService = (AuthService) getServletContext().getAttribute(AppContextListener.AUTH_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        if ("logout".equals(action)) {
            logout(request, response);
            return;
        }
        // đã đăng nhập rồi thì không cần vào trang đăng nhập / đăng ký nữa
        if (AuthFilter.getLoginUser(request) != null) {
            response.sendRedirect(request.getContextPath() + "/");
            return;
        }
        if ("register".equals(action)) {
            // JavaBean rỗng cho form đăng ký, chọn sẵn vai trò theo ?role=
            RegisterRequest form = new RegisterRequest();
            if (User.ROLE_OWNER.equals(request.getParameter("role"))) {
                form.setRole(User.ROLE_OWNER);
            } else {
                form.setRole(User.ROLE_CUSTOMER);
            }
            request.setAttribute("form", form);
            showRegister(request, response);
        } else {
            // mở trang đăng nhập: đọc cookie để điền sẵn SĐT / email đã ghi nhớ
            String rememberedPhone = readCookie(request, REMEMBER_COOKIE);
            if (rememberedPhone != null) {
                request.setAttribute("phoneOrEmail", rememberedPhone);
                request.setAttribute("remember", true);
            }
            showLogin(request, response);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        if ("login".equals(action)) {
            login(request, response);
        } else if ("register".equals(action)) {
            register(request, response);
        } else if ("logout".equals(action)) {
            logout(request, response);
        } else {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }

    // ===================== action=login =====================

    private void login(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String phoneOrEmail = getText(request, "phoneOrEmail").trim();
        String password = request.getParameter("password");
        boolean remember = "1".equals(request.getParameter("remember"));
        try {
            User user = authService.login(phoneOrEmail, password);
            saveToSession(request, user);
            saveRememberCookie(request, response, phoneOrEmail, remember);
            response.sendRedirect(nextUrl(request));
            return;
        } catch (AuthException e) {
            request.setAttribute("error", e.getMessage());
        }
        // sai -> hiện lại form, giữ ô SĐT/email (không giữ mật khẩu)
        request.setAttribute("phoneOrEmail", phoneOrEmail);
        request.setAttribute("remember", remember);
        showLogin(request, response);
    }

    // ===================== action=register =====================

    private void register(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        // 1. Đọc form vào JavaBean RegisterRequest
        RegisterRequest form = new RegisterRequest();
        form.setRole(request.getParameter("role"));
        form.setFullName(request.getParameter("fullName"));
        form.setPhone(request.getParameter("phone"));
        form.setCccd(request.getParameter("cccd"));
        form.setEmail(request.getParameter("email"));
        form.setPassword(request.getParameter("password"));
        form.setConfirmPassword(request.getParameter("confirmPassword"));

        // 2. Gọi Service kiểm tra + lưu
        try {
            User user = authService.register(form);
            // đăng ký xong thì đăng nhập luôn
            saveToSession(request, user);
            response.sendRedirect(nextUrl(request));
            return;
        } catch (AuthException e) {
            request.setAttribute("error", e.getMessage());
        }

        // 3. Sai -> hiện lại form bằng chính bean đó (xóa mật khẩu, không gửi ngược ra trang)
        form.setPassword(null);
        form.setConfirmPassword(null);
        request.setAttribute("form", form);
        showRegister(request, response);
    }

    // ===================== action=logout =====================

    private void logout(HttpServletRequest request, HttpServletResponse response) throws IOException {
        HttpSession session = request.getSession(false);
        if (session != null) {
            session.invalidate();
        }
        response.sendRedirect(request.getContextPath() + "/");
    }

    // ===================== hàm phụ =====================

    private void showLogin(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        request.setAttribute("next", getSafeNext(request));
        View.forward(request, response, "auth/login");
    }

    private void showRegister(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        request.setAttribute("next", getSafeNext(request));
        View.forward(request, response, "auth/register");
    }

    /** Lưu User vào session. Đổi session id sau khi đăng nhập để chống chiếm phiên (session fixation). */
    private static void saveToSession(HttpServletRequest request, User user) {
        HttpSession session = request.getSession(true);
        request.changeSessionId();
        session.setAttribute(AuthFilter.SESSION_USER, user);
    }

    /**
     * Có tick "Ghi nhớ" -> tạo cookie rememberPhone sống 30 ngày.
     * Không tick -> gửi cookie cùng tên với maxAge = 0 để trình duyệt xóa cookie cũ.
     */
    private static void saveRememberCookie(HttpServletRequest request, HttpServletResponse response,
                                           String phoneOrEmail, boolean remember) {
        Cookie cookie = new Cookie(REMEMBER_COOKIE, phoneOrEmail);
        if (remember) {
            cookie.setMaxAge(REMEMBER_SECONDS);
        } else {
            cookie.setValue("");
            cookie.setMaxAge(0);
        }
        // cookie chỉ gửi kèm các trang của web này
        String path = request.getContextPath();
        if (path.isEmpty()) {
            path = "/";
        }
        cookie.setPath(path);
        // JavaScript trên trang không đọc được cookie này
        cookie.setHttpOnly(true);
        response.addCookie(cookie);
    }

    /** Đọc giá trị 1 cookie theo tên; không có thì trả về null. */
    private static String readCookie(HttpServletRequest request, String name) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null) {
            return null;
        }
        for (int i = 0; i < cookies.length; i++) {
            Cookie cookie = cookies[i];
            if (name.equals(cookie.getName())) {
                String value = cookie.getValue();
                if (value == null || value.trim().isEmpty()) {
                    return null;
                }
                return value;
            }
        }
        return null;
    }

    /** Trang cần quay lại sau khi đăng nhập; không có thì về trang chủ. */
    private static String nextUrl(HttpServletRequest request) {
        String next = getSafeNext(request);
        if (next.isEmpty()) {
            return request.getContextPath() + "/";
        }
        return request.getContextPath() + next;
    }

    /**
     * Chỉ nhận đường dẫn nội bộ dạng "/viewings?..." để kẻ xấu không gửi link ?next=https://trang-gia-mao.com.
     * Không hợp lệ thì trả về chuỗi rỗng.
     */
    private static String getSafeNext(HttpServletRequest request) {
        String next = request.getParameter("next");
        if (next == null) {
            return "";
        }
        if (!next.startsWith("/") || next.startsWith("//") || next.contains("\\")) {
            return "";
        }
        if (next.contains("\r") || next.contains("\n")) {
            return "";
        }
        return next;
    }

    private static String getText(HttpServletRequest request, String name) {
        String value = request.getParameter(name);
        if (value == null) {
            return "";
        }
        return value;
    }
}
