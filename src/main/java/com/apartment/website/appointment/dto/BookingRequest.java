package com.apartment.website.appointment.dto;

/**
 * JavaBean: dữ liệu khách gửi từ form đặt lịch (chưa kiểm tra). Ứng với các cột của property_viewings.
 * schedule.jsp đọc lại ${form.customerName}, ${form.customerPhone}, ${form.note} để điền sẵn form.
 */
public class BookingRequest {
    private long propertyId;
    private String date;
    private String time;
    private String customerName;
    private String customerPhone;
    private String note;

    public BookingRequest() {
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    /** "2026-11-05" */
    public String getDate() {
        return date;
    }

    public void setDate(String date) {
        this.date = date;
    }

    /** "09:30" */
    public String getTime() {
        return time;
    }

    public void setTime(String time) {
        this.time = time;
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
}
