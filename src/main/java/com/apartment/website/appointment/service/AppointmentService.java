package com.apartment.website.appointment.service;

import com.apartment.website.appointment.dto.BookingRequest;
import com.apartment.website.appointment.dto.DaySlot;
import com.apartment.website.appointment.dto.SlotInfo;
import com.apartment.website.appointment.entity.PropertyViewing;
import com.apartment.website.appointment.repository.PropertyViewingRepository;
import com.apartment.website.common.exception.BookingException;
import com.apartment.website.notification.service.NotificationService;
import com.apartment.website.user.entity.User;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Quy tắc lịch hẹn xem nhà (bảng property_viewings):
 *  - Khách đặt lịch -> "Chờ xác nhận" -> báo cho chủ căn hộ.
 *  - Chủ căn hộ xác nhận / từ chối / đánh dấu hoàn thành / hủy -> báo cho khách.
 *  - Khách hủy lịch -> báo cho chủ căn hộ.
 */
public class AppointmentService {
    public static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    // còn <= 2 khung giờ thì hiện "Ít chỗ"
    public static final int FEW_LEFT = 2;
    // cho đặt tối đa tới hết tháng thứ (hiện tại + 3)
    public static final int MAX_MONTHS_AHEAD = 3;
    // giới hạn theo độ dài cột trong bảng property_viewings
    private static final int MAX_NAME = 150;
    private static final int MAX_NOTE = 1000;
    private static final int MAX_REASON = 500;

    // các thao tác trên trang "Lịch hẹn" (tham số action)
    public static final String ACTION_CONFIRM = "confirm";
    public static final String ACTION_REJECT = "reject";
    public static final String ACTION_COMPLETE = "complete";
    public static final String ACTION_CANCEL = "cancel";

    /** Các khung giờ xem nhà trong 1 ngày, mỗi khung 30 phút (DB bắt buộc end_time = start_time + 30 phút). */
    public static final List<String> SLOTS = new ArrayList<String>();

    static {
        SLOTS.add("08:30");
        SLOTS.add("09:30");
        SLOTS.add("10:30");
        SLOTS.add("13:30");
        SLOTS.add("14:30");
        SLOTS.add("15:30");
        SLOTS.add("16:30");
        SLOTS.add("17:30");
    }

    private final PropertyViewingRepository repository;
    private final NotificationService notificationService;

    public AppointmentService(PropertyViewingRepository repository, NotificationService notificationService) {
        this.repository = repository;
        this.notificationService = notificationService;
    }

    public LocalDate today() {
        return LocalDate.now(ZONE);
    }

    /** Ngày xa nhất được đặt: cuối tháng (hiện tại + 3). */
    public LocalDate maxDate() {
        YearMonth lastMonth = YearMonth.from(today()).plusMonths(MAX_MONTHS_AHEAD);
        return lastMonth.atEndOfMonth();
    }

    /** "2026-11" -> YearMonth, nằm trong khoảng cho phép; sai định dạng thì trả về tháng hiện tại. */
    public YearMonth parseMonth(String text) {
        YearMonth current = YearMonth.from(today());
        YearMonth month = current;
        if (text != null) {
            try {
                month = YearMonth.parse(text);
            } catch (DateTimeParseException e) {
                month = current;
            }
        }
        if (month.isBefore(current)) {
            return current;
        }
        YearMonth last = current.plusMonths(MAX_MONTHS_AHEAD);
        if (month.isAfter(last)) {
            return last;
        }
        return month;
    }

    // ===================== LỊCH & KHUNG GIỜ =====================

    /** Trạng thái từng ngày của một tháng (để vẽ lịch). */
    public List<DaySlot> month(long propertyId, YearMonth month) {
        LocalDate today = today();
        LocalDate firstDay = month.atDay(1);
        LocalDate lastDay = month.atEndOfMonth();
        Map<LocalDate, Integer> bookedByDay = repository.bookedCountByDay(propertyId, firstDay, lastDay);

        List<DaySlot> days = new ArrayList<DaySlot>();
        LocalDate day = firstDay;
        while (!day.isAfter(lastDay)) {
            DaySlot slot = new DaySlot();
            slot.setDate(day);
            if (day.isBefore(today)) {
                slot.setState(DaySlot.PAST);
                slot.setFree(0);
            } else {
                int free;
                if (day.equals(today)) {
                    // hôm nay: đếm lại từng khung giờ vì có giờ đã trôi qua
                    free = countAvailable(slots(propertyId, day));
                } else {
                    Integer booked = bookedByDay.get(day);
                    if (booked == null) {
                        booked = 0;
                    }
                    free = SLOTS.size() - booked;
                }

                String state;
                if (free <= 0) {
                    state = DaySlot.FULL;
                    free = 0;
                } else if (free <= FEW_LEFT) {
                    state = DaySlot.FEW;
                } else {
                    state = DaySlot.OPEN;
                }
                slot.setState(state);
                slot.setFree(free);
            }
            days.add(slot);
            day = day.plusDays(1);
        }
        return days;
    }

    private static int countAvailable(List<SlotInfo> slots) {
        int count = 0;
        for (int i = 0; i < slots.size(); i++) {
            if (slots.get(i).isAvailable()) {
                count++;
            }
        }
        return count;
    }

    /** Các khung giờ của 1 ngày, đánh dấu cái nào còn trống (trùng lịch khác hoặc đã qua giờ thì không trống). */
    public List<SlotInfo> slots(long propertyId, LocalDate date) {
        List<LocalDateTime> bookedStarts = repository.bookedStartTimes(propertyId, date);
        LocalDateTime now = LocalDateTime.now(ZONE);

        List<SlotInfo> result = new ArrayList<SlotInfo>();
        for (int i = 0; i < SLOTS.size(); i++) {
            String time = SLOTS.get(i);
            LocalDateTime slotStart = date.atTime(LocalTime.parse(time));
            LocalDateTime slotEnd = slotStart.plusMinutes(PropertyViewing.DURATION_MINUTES);

            boolean past = slotStart.isBefore(now);
            boolean overlap = false;
            for (int j = 0; j < bookedStarts.size(); j++) {
                LocalDateTime bookedStart = bookedStarts.get(j);
                LocalDateTime bookedEnd = bookedStart.plusMinutes(PropertyViewing.DURATION_MINUTES);
                // 2 khoảng [a, b) và [c, d) giao nhau khi a < d và c < b
                if (slotStart.isBefore(bookedEnd) && bookedStart.isBefore(slotEnd)) {
                    overlap = true;
                }
            }
            SlotInfo slot = new SlotInfo();
            slot.setTime(time);
            slot.setAvailable(!past && !overlap);
            result.add(slot);
        }
        return result;
    }

    // ===================== DỮ LIỆU CHO TRANG ĐẶT LỊCH =====================

    /**
     * Ngày đang chọn trên lịch.
     * ?date= hợp lệ (từ hôm nay tới maxDate) thì lấy ngày đó; không thì xem ?month=:
     * tháng này -> chọn hôm nay, tháng sau -> chọn ngày 1 của tháng.
     */
    public LocalDate chooseDate(String dateText, String monthText) {
        LocalDate today = today();
        LocalDate selected = null;
        if (dateText != null) {
            try {
                selected = LocalDate.parse(dateText);
            } catch (DateTimeParseException e) {
                selected = null;
            }
        }
        if (selected != null && !selected.isBefore(today) && !selected.isAfter(maxDate())) {
            return selected;
        }

        YearMonth month = parseMonth(monthText);
        if (month.equals(YearMonth.from(today))) {
            return today;
        }
        return month.atDay(1);
    }

    /**
     * Các ô của lịch tháng chứa ngày đang chọn, bắt đầu từ thứ 2.
     * Đầu tháng thêm các ô trống (blank) để ngày 1 rơi đúng cột thứ của nó.
     * baseUrl = "/ctx/appointments?propertyId=5" để ghép link chọn ngày.
     */
    public List<DaySlot> calendar(long propertyId, LocalDate selectedDate, String baseUrl) {
        YearMonth month = YearMonth.from(selectedDate);
        List<DaySlot> cells = new ArrayList<DaySlot>();

        // getDayOfWeek(): thứ 2 = 1 ... chủ nhật = 7
        int blankCells = month.atDay(1).getDayOfWeek().getValue() - 1;
        for (int i = 0; i < blankCells; i++) {
            DaySlot blank = new DaySlot();
            blank.setBlank(true);
            cells.add(blank);
        }

        List<DaySlot> days = month(propertyId, month);
        for (int i = 0; i < days.size(); i++) {
            DaySlot day = days.get(i);
            day.setSelected(day.getDate().equals(selectedDate));
            if (day.isClickable()) {
                day.setHref(baseUrl + "&date=" + day.getDate());
            } else {
                day.setHref(null);
            }
            cells.add(day);
        }
        return cells;
    }

    /**
     * Khung giờ của ngày đang chọn kèm link chọn giờ.
     * selectedTime là ?time= trên URL; chỉ được chọn nếu khung giờ đó còn trống.
     */
    public List<SlotInfo> timeSlots(long propertyId, LocalDate selectedDate, String selectedTime, String baseUrl) {
        List<SlotInfo> result = slots(propertyId, selectedDate);
        for (int i = 0; i < result.size(); i++) {
            SlotInfo slot = result.get(i);
            if (slot.isAvailable()) {
                slot.setSelected(slot.getTime().equals(selectedTime));
                slot.setHref(baseUrl + "&date=" + selectedDate + "&time=" + slot.getTime());
            } else {
                slot.setSelected(false);
                slot.setHref(null);
            }
        }
        return result;
    }

    /** Khung giờ đang được chọn (null nếu chưa chọn hoặc giờ đó đã hết chỗ). */
    public String selectedTime(List<SlotInfo> slots) {
        for (int i = 0; i < slots.size(); i++) {
            SlotInfo slot = slots.get(i);
            if (slot.isSelected()) {
                return slot.getTime();
            }
        }
        return null;
    }

    /** Tháng trước để bấm nút ‹ ; null nếu đang ở tháng hiện tại (không cho lùi về quá khứ). */
    public YearMonth previousMonth(YearMonth month) {
        YearMonth current = YearMonth.from(today());
        if (month.isAfter(current)) {
            return month.minusMonths(1);
        }
        return null;
    }

    /** Tháng sau để bấm nút › ; null nếu đã tới tháng xa nhất được đặt. */
    public YearMonth nextMonth(YearMonth month) {
        YearMonth last = YearMonth.from(today()).plusMonths(MAX_MONTHS_AHEAD);
        if (month.isBefore(last)) {
            return month.plusMonths(1);
        }
        return null;
    }

    // ===================== KHÁCH ĐẶT LỊCH =====================

    /**
     * Khách đặt lịch. Ném BookingException (dữ liệu sai) hoặc SlotTakenException (giờ đã bị đặt).
     * Thành công thì gửi thông báo cho chủ căn hộ và trả về viewing_id.
     */
    public long book(BookingRequest request, User customer) {
        if (customer == null || !customer.isCustomer()) {
            throw new BookingException("Chỉ tài khoản khách hàng mới đặt được lịch xem nhà.");
        }

        // 1. Ngày và giờ
        LocalDate date;
        try {
            date = LocalDate.parse(request.getDate());
        } catch (DateTimeParseException e) {
            throw new BookingException("Vui lòng chọn ngày xem nhà.");
        }
        if (!SLOTS.contains(request.getTime())) {
            throw new BookingException("Vui lòng chọn một khung giờ xem nhà.");
        }
        if (date.isBefore(today()) || date.isAfter(maxDate())) {
            throw new BookingException("Ngày đã chọn không hợp lệ.");
        }
        LocalDateTime startTime = date.atTime(LocalTime.parse(request.getTime()));
        if (startTime.isBefore(LocalDateTime.now(ZONE))) {
            throw new BookingException("Khung giờ này đã qua, vui lòng chọn giờ khác.");
        }

        // 2. Thông tin liên hệ (mặc định lấy từ tài khoản, khách có thể sửa)
        String name = trimText(request.getCustomerName()).replaceAll("\\s+", " ");
        String phone = trimText(request.getCustomerPhone()).replaceAll("[\\s.\\-]", "");
        String note = trimText(request.getNote());
        if (name.isEmpty() || name.length() > MAX_NAME) {
            throw new BookingException("Vui lòng nhập họ và tên (tối đa " + MAX_NAME + " ký tự).");
        }
        if (!phone.matches("^(0|\\+84)\\d{9,10}$")) {
            throw new BookingException("Số điện thoại không hợp lệ (ví dụ 0901234567).");
        }
        if (note.length() > MAX_NOTE) {
            throw new BookingException("Ghi chú tối đa " + MAX_NOTE + " ký tự.");
        }

        // 3. Lưu: status = Chờ xác nhận, end_time = start_time + 30 phút
        PropertyViewing viewing = new PropertyViewing();
        viewing.setCustomerId(customer.getUserId());
        viewing.setPropertyId(request.getPropertyId());
        viewing.setStartTime(startTime);
        viewing.setEndTime(startTime.plusMinutes(PropertyViewing.DURATION_MINUTES));
        viewing.setStatus(PropertyViewing.PENDING);
        viewing.setCustomerName(name);
        viewing.setCustomerPhone(phone);
        if (note.isEmpty()) {
            viewing.setNote(null);
        } else {
            viewing.setNote(note);
        }
        long viewingId = repository.create(viewing);

        // 4. Báo cho chủ căn hộ (owner_id do trigger điền -> đọc lại để biết)
        PropertyViewing saved = repository.findById(viewingId);
        if (saved != null) {
            String message = "Khách " + saved.getCustomerName() + " (" + saved.getCustomerPhone() + ") muốn xem căn \""
                    + saved.getPropertyTitle() + "\" lúc " + saved.getTimeText() + " ngày " + saved.getDateText()
                    + ". Vui lòng xác nhận lịch hẹn.";
            notificationService.notifyViewing(saved.getOwnerId(), "Lịch hẹn mới chờ xác nhận", message, viewingId);
        }
        return viewingId;
    }

    // ===================== TRANG "LỊCH HẸN" =====================

    /** Chủ căn hộ thấy lịch hẹn của các căn mình; khách thấy lịch mình đã đặt. */
    public List<PropertyViewing> viewingsOf(User user) {
        if (user.isOwner()) {
            return repository.findByOwner(user.getUserId());
        }
        return repository.findByCustomer(user.getUserId());
    }

    /** Trả về null nếu không tìm thấy. */
    public PropertyViewing findById(long viewingId) {
        return repository.findById(viewingId);
    }

    /**
     * Đổi trạng thái 1 lịch hẹn theo thao tác action rồi gửi thông báo cho bên còn lại.
     * Trả về câu thông báo thành công. Sai quyền / sai trạng thái thì ném BookingException.
     */
    public String changeStatus(long viewingId, User user, String action, String reasonText) {
        PropertyViewing viewing = repository.findById(viewingId);
        if (viewing == null) {
            throw new BookingException("Không tìm thấy lịch hẹn.");
        }
        String reason = trimText(reasonText);
        if (reason.length() > MAX_REASON) {
            throw new BookingException("Lý do tối đa " + MAX_REASON + " ký tự.");
        }
        if (reason.isEmpty()) {
            reason = null;
        }

        if (user.isOwner()) {
            return changeByOwner(viewing, user, action, reason);
        }
        if (user.isCustomer()) {
            return changeByCustomer(viewing, user, action, reason);
        }
        throw new BookingException("Tài khoản này không thao tác được lịch hẹn.");
    }

    private String changeByOwner(PropertyViewing viewing, User owner, String action, String reason) {
        String fromStatus;
        String toStatus;
        String title;
        String result;
        if (ACTION_CONFIRM.equals(action)) {
            fromStatus = PropertyViewing.PENDING;
            toStatus = PropertyViewing.CONFIRMED;
            title = "Lịch hẹn đã được xác nhận";
            result = "Đã xác nhận lịch hẹn.";
        } else if (ACTION_REJECT.equals(action)) {
            fromStatus = PropertyViewing.PENDING;
            toStatus = PropertyViewing.REJECTED;
            title = "Lịch hẹn bị từ chối";
            result = "Đã từ chối lịch hẹn.";
        } else if (ACTION_COMPLETE.equals(action)) {
            fromStatus = PropertyViewing.CONFIRMED;
            toStatus = PropertyViewing.COMPLETED;
            title = "Lịch hẹn đã hoàn thành";
            result = "Đã đánh dấu hoàn thành.";
            if (viewing.getStartTime().isAfter(LocalDateTime.now(ZONE))) {
                throw new BookingException("Chưa tới giờ xem nhà nên chưa thể đánh dấu hoàn thành.");
            }
        } else if (ACTION_CANCEL.equals(action)) {
            fromStatus = PropertyViewing.CONFIRMED;
            toStatus = PropertyViewing.CANCELLED;
            title = "Lịch hẹn đã bị hủy";
            result = "Đã hủy lịch hẹn.";
        } else {
            throw new BookingException("Thao tác không hợp lệ.");
        }

        boolean changed = repository.changeStatus(viewing.getViewingId(), owner.getUserId(), true,
                fromStatus, toStatus, reason);
        if (!changed) {
            throw new BookingException("Lịch hẹn này đã đổi trạng thái hoặc không thuộc căn của bạn. Vui lòng tải lại trang.");
        }

        // báo cho khách
        String message = "Lịch xem căn \"" + viewing.getPropertyTitle() + "\" lúc " + viewing.getTimeText()
                + " ngày " + viewing.getDateText() + " đã chuyển sang: " + toStatus + ".";
        if (reason != null) {
            message = message + " Lý do: " + reason;
        }
        notificationService.notifyViewing(viewing.getCustomerId(), title, message, viewing.getViewingId());
        return result;
    }

    private String changeByCustomer(PropertyViewing viewing, User customer, String action, String reason) {
        if (!ACTION_CANCEL.equals(action)) {
            throw new BookingException("Khách hàng chỉ có thể hủy lịch hẹn.");
        }
        // khách hủy được khi lịch đang chờ hoặc đã xác nhận
        boolean changed = repository.changeStatus(viewing.getViewingId(), customer.getUserId(), false,
                PropertyViewing.PENDING, PropertyViewing.CANCELLED, reason);
        if (!changed) {
            changed = repository.changeStatus(viewing.getViewingId(), customer.getUserId(), false,
                    PropertyViewing.CONFIRMED, PropertyViewing.CANCELLED, reason);
        }
        if (!changed) {
            throw new BookingException("Lịch hẹn này không thể hủy nữa. Vui lòng tải lại trang.");
        }

        // báo cho chủ căn hộ
        String message = "Khách " + viewing.getCustomerName() + " đã hủy lịch xem căn \"" + viewing.getPropertyTitle()
                + "\" lúc " + viewing.getTimeText() + " ngày " + viewing.getDateText() + ".";
        if (reason != null) {
            message = message + " Lý do: " + reason;
        }
        notificationService.notifyViewing(viewing.getOwnerId(), "Khách đã hủy lịch hẹn", message, viewing.getViewingId());
        return "Đã hủy lịch hẹn.";
    }

    private static String trimText(String text) {
        if (text == null) {
            return "";
        }
        return text.trim();
    }
}
