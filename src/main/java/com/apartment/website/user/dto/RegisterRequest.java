package com.apartment.website.user.dto;

/**
 * JavaBean: dữ liệu form đăng ký (chưa kiểm tra). Chỉ gồm các cột có trong bảng users:
 * role, full_name, phone (= username), cccd, email, password_hash (= password).
 * Nhập sai thì AuthServlet gửi lại chính bean này cho register.jsp (${form.fullName}...) để giữ những gì đã nhập.
 */
public class RegisterRequest {
    private String role;
    private String fullName;
    private String phone;
    private String cccd;
    private String email;
    private String password;
    private String confirmPassword;

    public RegisterRequest() {
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public String getFullName() {
        return fullName;
    }

    public void setFullName(String fullName) {
        this.fullName = fullName;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getCccd() {
        return cccd;
    }

    public void setCccd(String cccd) {
        this.cccd = cccd;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getConfirmPassword() {
        return confirmPassword;
    }

    public void setConfirmPassword(String confirmPassword) {
        this.confirmPassword = confirmPassword;
    }
}
