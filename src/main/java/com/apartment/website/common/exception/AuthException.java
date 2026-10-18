package com.apartment.website.common.exception;

/** Đăng nhập / đăng ký không hợp lệ; getMessage() là câu tiếng Việt hiển thị cho người dùng. */
public class AuthException extends RuntimeException {
    public AuthException(String message) {
        super(message);
    }
}
