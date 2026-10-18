package com.apartment.website.user.entity;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Tài khoản người dùng (bảng users). Lớp cha của Customer, Owner, Admin -> đúng mũi tên "Inheritance" trong diagram.
 * Mỗi field ứng với 1 cột của bảng users. Đăng nhập xong, object này được cất vào session (nên phải Serializable).
 * Lưu ý DB: username luôn bằng phone (CHECK chk_username_equals_phone).
 */
public class User implements Serializable {
    private static final long serialVersionUID = 1L;
    private static final DateTimeFormatter MONTH_FORMAT = DateTimeFormatter.ofPattern("MM/yyyy");

    public static final String ROLE_ADMIN = "ADMIN";
    public static final String ROLE_CUSTOMER = "CUSTOMER";
    public static final String ROLE_OWNER = "OWNER";

    private long userId;
    private String username;
    private String email;
    private String passwordHash;
    private String role;
    private LocalDateTime createdAt;
    private boolean active;
    private String fullName;
    private String phone;
    private String cccd;
    private LocalDateTime updatedAt;
    private LocalDateTime lastLoginAt;
    private String blockedReason;
    private LocalDateTime blockedAt;
    private Long blockedBy;

    public User() {
    }

    public long getUserId() {
        return userId;
    }

    public void setUserId(long userId) {
        this.userId = userId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
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

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public LocalDateTime getLastLoginAt() {
        return lastLoginAt;
    }

    public void setLastLoginAt(LocalDateTime lastLoginAt) {
        this.lastLoginAt = lastLoginAt;
    }

    public String getBlockedReason() {
        return blockedReason;
    }

    public void setBlockedReason(String blockedReason) {
        this.blockedReason = blockedReason;
    }

    public LocalDateTime getBlockedAt() {
        return blockedAt;
    }

    public void setBlockedAt(LocalDateTime blockedAt) {
        this.blockedAt = blockedAt;
    }

    public Long getBlockedBy() {
        return blockedBy;
    }

    public void setBlockedBy(Long blockedBy) {
        this.blockedBy = blockedBy;
    }

    // ===== các getter tự tính cho JSP =====

    /** JSP: ${currentUser.owner} -> true nếu là chủ căn hộ. */
    public boolean isOwner() {
        return ROLE_OWNER.equals(role);
    }

    /** JSP: ${currentUser.customer} -> true nếu là khách hàng. */
    public boolean isCustomer() {
        return ROLE_CUSTOMER.equals(role);
    }

    /** JSP: ${currentUser.admin} -> true nếu là quản trị viên. */
    public boolean isAdmin() {
        return ROLE_ADMIN.equals(role);
    }

    /** "Chủ căn hộ" / "Khách hàng" / "Quản trị viên" */
    public String getRoleText() {
        if (ROLE_OWNER.equals(role)) {
            return "Chủ căn hộ";
        }
        if (ROLE_CUSTOMER.equals(role)) {
            return "Khách hàng";
        }
        return "Quản trị viên";
    }

    /** "0901234567" -> "0901 234 567" cho dễ đọc; số dạng khác thì giữ nguyên. */
    public String getPhoneText() {
        if (phone == null) {
            return "";
        }
        if (phone.matches("0\\d{9}")) {
            return phone.substring(0, 4) + " " + phone.substring(4, 7) + " " + phone.substring(7);
        }
        return phone;
    }

    /** Chữ cái đầu của tên cuối, làm avatar: "Nguyễn Văn Hùng" -> "H". */
    public String getInitial() {
        if (fullName == null || fullName.trim().isEmpty()) {
            return "?";
        }
        String[] words = fullName.trim().split("\\s+");
        String lastWord = words[words.length - 1];
        return lastWord.substring(0, 1).toUpperCase();
    }

    /** JSP: ${owner.memberSince} -> "10/2026". */
    public String getMemberSince() {
        if (createdAt == null) {
            return "";
        }
        return createdAt.format(MONTH_FORMAT);
    }
}
