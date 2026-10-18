package com.apartment.website.common.exception;

/** Dữ liệu đặt lịch không hợp lệ; getMessage() là câu tiếng Việt hiển thị cho người dùng. */
public class BookingException extends RuntimeException {
    public BookingException(String message) {
        super(message);
    }
}
