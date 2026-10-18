package com.apartment.website.common.exception;

/** Dữ liệu đánh giá không hợp lệ; getMessage() là câu tiếng Việt hiển thị cho người dùng. */
public class ReviewException extends RuntimeException {
    public ReviewException(String message) {
        super(message);
    }
}
