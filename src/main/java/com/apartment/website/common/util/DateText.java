package com.apartment.website.common.util;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/** Định dạng ngày kiểu Việt Nam để hiển thị trên JSP. */
public final class DateText {
    private static final String[] DAY_OF_WEEK = {"Thứ hai", "Thứ ba", "Thứ tư", "Thứ năm", "Thứ sáu", "Thứ bảy", "Chủ nhật"};
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private DateText() {
    }

    /** 2026-11-05 -> "Thứ năm, 05/11/2026" */
    public static String fullDate(LocalDate date) {
        if (date == null) {
            return "";
        }
        // getDayOfWeek(): thứ 2 = 1 ... chủ nhật = 7
        int dayIndex = date.getDayOfWeek().getValue() - 1;
        return DAY_OF_WEEK[dayIndex] + ", " + date.format(DATE_FORMAT);
    }
}
