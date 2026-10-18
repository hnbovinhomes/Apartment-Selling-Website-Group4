package com.apartment.website.appointment.dto;

/**
 * JavaBean: 1 khung giờ trong ngày đang chọn và còn trống hay không.
 * schedule.jsp đọc: ${slot.time}, ${slot.cls}, ${slot.href}.
 */
public class SlotInfo {
    private String time;
    private boolean available;
    private boolean selected;
    private String href;

    public SlotInfo() {
    }

    /** "09:30" */
    public String getTime() {
        return time;
    }

    public void setTime(String time) {
        this.time = time;
    }

    public boolean isAvailable() {
        return available;
    }

    public void setAvailable(boolean available) {
        this.available = available;
    }

    public boolean isSelected() {
        return selected;
    }

    public void setSelected(boolean selected) {
        this.selected = selected;
    }

    /** Link chọn giờ; null = không bấm được. */
    public String getHref() {
        return href;
    }

    public void setHref(String href) {
        this.href = href;
    }

    /** Class CSS: hết chỗ thì mờ đi, đang chọn thì tô màu. */
    public String getCls() {
        if (!available) {
            return "is-disabled";
        }
        if (selected) {
            return "is-selected";
        }
        return "";
    }
}
