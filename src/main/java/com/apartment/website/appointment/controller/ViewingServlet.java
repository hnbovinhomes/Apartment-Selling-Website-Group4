package com.apartment.website.appointment.controller;

import com.apartment.website.appointment.entity.PropertyViewing;
import com.apartment.website.appointment.service.AppointmentService;
import com.apartment.website.common.exception.BookingException;
import com.apartment.website.common.filter.AuthFilter;
import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.user.entity.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * Trang "Lịch hẹn" (cần đăng nhập, AuthFilter đã kiểm tra):
 *  GET  /viewings?status=all|pending|confirmed|closed  -> danh sách lịch hẹn -> views/viewing/list.jsp
 *       Chủ căn hộ: lịch của các căn mình. Khách hàng: lịch mình đã đặt.
 *  POST /viewings  (action=confirm|reject|complete|cancel, id=<viewing_id>, reason=...)
 *       -> đổi trạng thái, gửi thông báo cho bên còn lại, rồi redirect về GET
 */
public class ViewingServlet extends HttpServlet {
    /** Câu thông báo xanh hiện 1 lần sau khi redirect (lưu tạm trong session). */
    private static final String FLASH = "viewingFlash";

    private AppointmentService appointmentService;

    @Override
    public void init() {
        appointmentService = (AppointmentService) getServletContext().getAttribute(AppContextListener.APPOINTMENT_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        showList(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        User user = AuthFilter.getLoginUser(request);
        String action = request.getParameter("action");
        Long id = toLong(request.getParameter("id"));
        if (id == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        try {
            String message = appointmentService.changeStatus(id, user, action, request.getParameter("reason"));
            HttpSession session = request.getSession(true);
            session.setAttribute(FLASH, message);
            // giữ nguyên tab đang xem, cuộn tới đúng lịch vừa thao tác
            response.sendRedirect(request.getContextPath() + "/viewings?status=" + getStatusTab(request) + "#v" + id);
            return;
        } catch (BookingException e) {
            request.setAttribute("error", e.getMessage());
        }
        showList(request, response);
    }

    private void showList(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        User user = AuthFilter.getLoginUser(request);
        List<PropertyViewing> all = appointmentService.viewingsOf(user);
        String tab = getStatusTab(request);

        // lọc theo tab và đếm số lịch của từng tab
        List<PropertyViewing> shown = new ArrayList<PropertyViewing>();
        int pendingCount = 0;
        int confirmedCount = 0;
        int closedCount = 0;
        for (int i = 0; i < all.size(); i++) {
            PropertyViewing viewing = all.get(i);
            String group;
            if (viewing.isPending()) {
                group = "pending";
                pendingCount++;
            } else if (viewing.isConfirmed()) {
                group = "confirmed";
                confirmedCount++;
            } else {
                group = "closed";
                closedCount++;
            }
            if (tab.equals("all") || tab.equals(group)) {
                shown.add(viewing);
            }
        }

        // thông báo xanh sau khi redirect: đọc xong thì xóa
        HttpSession session = request.getSession(false);
        if (session != null && session.getAttribute(FLASH) != null) {
            request.setAttribute("message", session.getAttribute(FLASH));
            session.removeAttribute(FLASH);
        }

        request.setAttribute("active", "viewings");
        request.setAttribute("viewings", shown);
        request.setAttribute("tab", tab);
        request.setAttribute("totalCount", all.size());
        request.setAttribute("pendingCount", pendingCount);
        request.setAttribute("confirmedCount", confirmedCount);
        request.setAttribute("closedCount", closedCount);
        View.forward(request, response, "viewing/list");
    }

    /** Tab đang chọn: all (mặc định) | pending | confirmed | closed. */
    private static String getStatusTab(HttpServletRequest request) {
        String status = request.getParameter("status");
        if ("pending".equals(status) || "confirmed".equals(status) || "closed".equals(status)) {
            return status;
        }
        return "all";
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
