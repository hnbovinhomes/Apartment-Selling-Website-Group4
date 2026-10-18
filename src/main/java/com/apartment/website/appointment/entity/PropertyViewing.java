package com.apartment.website.appointment.entity;

import com.apartment.website.common.util.DateText;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Một lịch hẹn xem nhà (bảng property_viewings). Diagram: Customer 1 --- 0..* PropertyViewing 0..* --- 1 Property.
 * DB ràng buộc:
 *  - end_time = start_time + 30 phút (chk_viewing_duration)
 *  - owner_id do trigger tự điền từ apartments.owner_id
 *  - không cho 2 lịch trùng giờ của cùng 1 căn (no_overlapping_viewings)
 * propertyTitle, ownerName, ownerPhone, customerFullName không phải cột của bảng: lấy thêm khi JOIN để hiển thị.
 */
public class PropertyViewing {
    // các giá trị cột status (CHECK property_viewings_status_check) - lưu bằng tiếng Việt
    public static final String PENDING = "Chờ xác nhận";
    public static final String CONFIRMED = "Đã xác nhận";
    public static final String COMPLETED = "Đã hoàn thành";
    public static final String CANCELLED = "Đã hủy";
    public static final String REJECTED = "Đã từ chối";
    public static final int DURATION_MINUTES = 30;

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");

    private long viewingId;
    private long customerId;
    private long propertyId;
    private long ownerId;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private String status;
    private String customerName;
    private String customerPhone;
    private String note;
    private String cancellationReason;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // lấy thêm khi JOIN để hiển thị
    private String propertyTitle;
    private String ownerName;
    private String ownerPhone;

    public PropertyViewing() {
    }

    public long getViewingId() {
        return viewingId;
    }

    public void setViewingId(long viewingId) {
        this.viewingId = viewingId;
    }

    public long getCustomerId() {
        return customerId;
    }

    public void setCustomerId(long customerId) {
        this.customerId = customerId;
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public long getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(long ownerId) {
        this.ownerId = ownerId;
    }

    public LocalDateTime getStartTime() {
        return startTime;
    }

    public void setStartTime(LocalDateTime startTime) {
        this.startTime = startTime;
    }

    public LocalDateTime getEndTime() {
        return endTime;
    }

    public void setEndTime(LocalDateTime endTime) {
        this.endTime = endTime;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getCustomerName() {
        return customerName;
    }

    public void setCustomerName(String customerName) {
        this.customerName = customerName;
    }

    public String getCustomerPhone() {
        return customerPhone;
    }

    public void setCustomerPhone(String customerPhone) {
        this.customerPhone = customerPhone;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public String getCancellationReason() {
        return cancellationReason;
    }

    public void setCancellationReason(String cancellationReason) {
        this.cancellationReason = cancellationReason;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public String getPropertyTitle() {
        return propertyTitle;
    }

    public void setPropertyTitle(String propertyTitle) {
        this.propertyTitle = propertyTitle;
    }

    public String getOwnerName() {
        return ownerName;
    }

    public void setOwnerName(String ownerName) {
        this.ownerName = ownerName;
    }

    public String getOwnerPhone() {
        return ownerPhone;
    }

    public void setOwnerPhone(String ownerPhone) {
        this.ownerPhone = ownerPhone;
    }

    // ===== các getter tự tính cho JSP =====

    /** JSP: ${v.dateText} -> "12/10/2026" */
    public String getDateText() {
        if (startTime == null) {
            return "";
        }
        return startTime.format(DATE_FORMAT);
    }

    /** JSP: ${booked.fullDateText} -> "Thứ hai, 12/10/2026" */
    public String getFullDateText() {
        if (startTime == null) {
            return "";
        }
        return DateText.fullDate(startTime.toLocalDate());
    }

    /** JSP: ${v.timeText} -> "09:00 - 09:30" */
    public String getTimeText() {
        if (startTime == null || endTime == null) {
            return "";
        }
        return startTime.format(TIME_FORMAT) + " - " + endTime.format(TIME_FORMAT);
    }

    /** Tên class CSS cho nhãn trạng thái: is-pending, is-confirmed... */
    public String getStatusClass() {
        if (PENDING.equals(status)) {
            return "is-pending";
        }
        if (CONFIRMED.equals(status)) {
            return "is-confirmed";
        }
        if (COMPLETED.equals(status)) {
            return "is-completed";
        }
        return "is-cancelled";
    }

    /** JSP: ${v.pending} */
    public boolean isPending() {
        return PENDING.equals(status);
    }

    /** JSP: ${v.confirmed} */
    public boolean isConfirmed() {
        return CONFIRMED.equals(status);
    }
}
