package com.apartment.website.common.exception;

/** Thao tác tin đăng không hợp lệ; getMessage() là câu tiếng Việt hiển thị cho người dùng. */
public class ListingException extends RuntimeException {
    public ListingException(String message) {
        super(message);
    }
}
