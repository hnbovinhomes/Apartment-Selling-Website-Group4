package com.apartment.website.appointment.controller;

import com.apartment.website.appointment.dto.BookingRequest;
import com.apartment.website.appointment.dto.DaySlot;
import com.apartment.website.appointment.dto.SlotInfo;
import com.apartment.website.appointment.entity.PropertyViewing;
import com.apartment.website.appointment.service.AppointmentService;
import com.apartment.website.common.exception.BookingException;
import com.apartment.website.common.exception.SlotTakenException;
import com.apartment.website.common.filter.AuthFilter;
import com.apartment.website.common.util.DateText;
import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.property.entity.Property;
import com.apartment.website.property.service.PropertyService;
import com.apartment.website.user.entity.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

/**
 * /appointments?propertyId=1&month=2026-11&date=2026-11-05&time=09:30  (khai báo trong web.xml)
 *  GET  : vẽ lịch, khung giờ, form. Chọn ngày / giờ = bấm vào liên kết (đổi tham số trên URL), không cần JavaScript.
 *         Ai cũng xem được lịch trống; chỉ KHÁCH HÀNG đã đăng nhập mới thấy form đặt lịch.
 *  POST : khách gửi form -> kiểm tra -> lưu vào property_viewings (Chờ xác nhận) -> báo cho chủ căn hộ
 *         -> chuyển hướng về GET kèm &booked=<viewing_id>.
 * Servlet chỉ đọc tham số, gọi AppointmentService và chuyển sang JSP; việc tính lịch / khung giờ nằm ở Service và JavaBean.
 */
public class AppointmentServlet extends HttpServlet {
    private AppointmentService appointmentService;
    private PropertyService propertyService;

    @Override
    public void init() {
        appointmentService = (AppointmentService) getServletContext().getAttribute(AppContextListener.APPOINTMENT_SERVICE);
        propertyService = (PropertyService) getServletContext().getAttribute(AppContextListener.PROPERTY_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        show(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Long propertyId = toLong(request.getParameter("propertyId"));
        if (propertyId == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        // chưa đăng nhập -> đăng nhập xong quay lại đúng trang đặt lịch của căn này
        User user = AuthFilter.getLoginUser(request);
        if (user == null) {
            String next = "/appointments?propertyId=" + propertyId;
            response.sendRedirect(request.getContextPath() + "/auth?action=login&next=" + encode(next));
            return;
        }

        // 1. Đọc form vào JavaBean BookingRequest
        BookingRequest booking = new BookingRequest();
        booking.setPropertyId(propertyId);
        booking.setDate(getText(request, "date"));
        booking.setTime(getText(request, "time"));
        booking.setCustomerName(getText(request, "customerName"));
        booking.setCustomerPhone(getText(request, "customerPhone"));
        booking.setNote(getText(request, "note"));

        // 2. Gọi Service kiểm tra + lưu
        try {
            long viewingId = appointmentService.book(booking, user);
            // redirect để F5 không gửi lại form
            response.sendRedirect(request.getContextPath() + "/appointments?propertyId=" + propertyId
                    + "&booked=" + viewingId);
            return;
        } catch (SlotTakenException e) {
            request.setAttribute("error", "Khung giờ này vừa có người đặt. Vui lòng chọn khung giờ khác.");
        } catch (BookingException e) {
            request.setAttribute("error", e.getMessage());
        }

        // 3. Sai -> hiện lại trang, gửi lại chính bean đó để giữ những gì người dùng đã nhập
        request.setAttribute("form", booking);
        show(request, response);
    }

    private void show(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        // 1. Căn hộ cần đặt lịch
        Property property = findProperty(request);
        if (property == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        long propertyId = property.getPropertyId();
        String baseUrl = request.getContextPath() + "/appointments?propertyId=" + propertyId;

        // 2. Đọc ?date, ?month, ?time rồi nhờ Service tính lịch tháng + khung giờ
        LocalDate selectedDate = appointmentService.chooseDate(request.getParameter("date"), request.getParameter("month"));
        YearMonth month = YearMonth.from(selectedDate);
        List<DaySlot> cells = appointmentService.calendar(propertyId, selectedDate, baseUrl);
        List<SlotInfo> slots = appointmentService.timeSlots(propertyId, selectedDate, request.getParameter("time"), baseUrl);
        String selectedTime = appointmentService.selectedTime(slots);

        // 3. Nút tháng trước / tháng sau (null = không bấm được)
        String previousHref = null;
        YearMonth previousMonth = appointmentService.previousMonth(month);
        if (previousMonth != null) {
            previousHref = baseUrl + "&month=" + previousMonth;
        }
        String nextHref = null;
        YearMonth nextMonth = appointmentService.nextMonth(month);
        if (nextMonth != null) {
            nextHref = baseUrl + "&month=" + nextMonth;
        }

        // 4. Ai đang xem trang: khách (đặt được), chủ căn hộ / chưa đăng nhập (chỉ xem)
        User user = AuthFilter.getLoginUser(request);
        boolean canBook = user != null && user.isCustomer();
        // lần đầu mở form: điền sẵn họ tên, SĐT trong tài khoản
        if (canBook && request.getAttribute("form") == null) {
            BookingRequest form = new BookingRequest();
            form.setCustomerName(user.getFullName());
            form.setCustomerPhone(user.getPhone());
            request.setAttribute("form", form);
        }
        String loginUrl = request.getContextPath() + "/auth?action=login&next="
                + encode("/appointments?propertyId=" + propertyId);

        // 5. Lịch vừa đặt xong (?booked=id): chỉ hiện cho đúng khách đã đặt lịch đó
        Long bookedId = toLong(request.getParameter("booked"));
        if (bookedId != null && user != null) {
            PropertyViewing viewing = appointmentService.findById(bookedId);
            if (viewing != null && viewing.getCustomerId() == user.getUserId()) {
                request.setAttribute("booked", viewing);
            }
        }

        String timeText = "Chưa chọn";
        if (selectedTime != null) {
            timeText = selectedTime;
        }

        // 6. Gửi dữ liệu sang JSP
        request.setAttribute("active", "schedule");
        request.setAttribute("property", property);
        request.setAttribute("monthTitle", "Tháng " + month.getMonthValue() + ", " + month.getYear());
        request.setAttribute("prevHref", previousHref);
        request.setAttribute("nextHref", nextHref);
        request.setAttribute("cells", cells);
        request.setAttribute("slots", slots);
        request.setAttribute("selectedDate", selectedDate.toString());
        request.setAttribute("selectedTime", selectedTime);
        request.setAttribute("dateText", DateText.fullDate(selectedDate));
        request.setAttribute("timeText", timeText);
        request.setAttribute("canBook", canBook);
        request.setAttribute("isOwnerViewer", user != null && user.isOwner());
        request.setAttribute("loginUrl", loginUrl);
        request.setAttribute("ownerAccount", propertyService.ownerOf(propertyId));
        View.forward(request, response, "appointment/schedule");
    }

    /** Có propertyId thì lấy căn đó, không thì lấy căn mới nhất để trang vẫn hiển thị được. Không có căn nào thì null. */
    private Property findProperty(HttpServletRequest request) {
        Long id = toLong(request.getParameter("propertyId"));
        if (id != null) {
            return propertyService.findById(id);
        }
        List<Property> featured = propertyService.featured(1);
        if (featured.isEmpty()) {
            return null;
        }
        return featured.get(0);
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

    /** Tham số không có thì trả về chuỗi rỗng thay vì null. */
    private static String getText(HttpServletRequest request, String name) {
        String value = request.getParameter(name);
        if (value == null) {
            return "";
        }
        return value;
    }

    private static String encode(String text) {
        return URLEncoder.encode(text, StandardCharsets.UTF_8);
    }
}
