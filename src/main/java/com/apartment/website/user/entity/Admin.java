package com.apartment.website.user.entity;

/**
 * Quản trị viên (users.role = 'ADMIN') -> kế thừa User. DB không có bảng admins riêng nên adminId = userId.
 * manageSystem() / manageUsers() / manageProperties() của diagram sẽ nằm ở AdminService.
 */
public class Admin extends User {
    private static final long serialVersionUID = 1L;

    public Admin() {
        setRole(ROLE_ADMIN);
    }

    public long getAdminId() {
        return getUserId();
    }
}
