package com.apartment.website.appointment.dto;

import java.time.LocalDate;

/**
 * JavaBean: 1 ô trên lịch tháng ở trang đặt lịch.
 * state: PAST (đã qua) | FULL (hết lịch) | FEW (ít chỗ) | OPEN (còn lịch).
 * blank = true là ô trống đầu tháng (để ngày 1 rơi đúng cột thứ).
 * schedule.jsp đọc: ${cell.blank}, ${cell.day}, ${cell.cls}, ${cell.label}, ${cell.href}.
 */
public class DaySlot {
    public static final String PAST = "PAST";
    public static final String FULL = "FULL";
    public static final String FEW = "FEW";
    public static final String OPEN = "OPEN";

    private LocalDate date;
    private String state;
    private int free;
    private boolean blank;
    private boolean selected;
    private String href;

    public DaySlot() {
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public String getState() {
        return state;
    }

    public void setState(String state) {
        this.state = state;
    }

    /** Số khung giờ còn trống trong ngày. */
    public int getFree() {
        return free;
    }

    public void setFree(int free) {
        this.free = free;
    }

    public boolean isBlank() {
        return blank;
    }

    public void setBlank(boolean blank) {
        this.blank = blank;
    }

    /** Ngày đang được chọn. */
    public boolean isSelected() {
        return selected;
    }

    public void setSelected(boolean selected) {
        this.selected = selected;
    }

    /** Link chọn ngày; null = không bấm được (ngày đã qua / hết lịch). */
    public String getHref() {
        return href;
    }

    public void setHref(String href) {
        this.href = href;
    }

    /** Số ngày trong tháng (1..31). */
    public int getDay() {
        if (date == null) {
            return 0;
        }
        return date.getDayOfMonth();
    }

    /** Class CSS theo trạng thái ngày. */
    public String getCls() {
        String cls;
        if (PAST.equals(state)) {
            cls = "is-past";
        } else if (FULL.equals(state)) {
            cls = "is-full";
        } else if (FEW.equals(state)) {
            cls = "is-few";
        } else {
            cls = "";
        }
        if (selected) {
            cls = cls + " is-selected";
        }
        return cls.trim();
    }

    /** Chữ nhỏ dưới số ngày. */
    public String getLabel() {
        if (PAST.equals(state)) {
            return "Đã qua";
        }
        if (FULL.equals(state)) {
            return "Hết lịch";
        }
        if (FEW.equals(state)) {
            return "Ít chỗ";
        }
        return "Còn lịch";
    }

    /** Ngày còn đặt được thì mới bấm vào được. */
    public boolean isClickable() {
        return FEW.equals(state) || OPEN.equals(state);
    }
}
