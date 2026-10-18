package com.apartment.website.user.entity;

/**
 * Khách hàng (bảng customers, customer_id = users.user_id) -> kế thừa User.
 * Bảng customers chỉ có 1 cột customer_id nên Customer không có field riêng.
 * searchProperties(), compareProperties(), bookViewing(), writeReview() của diagram
 * được hiện thực ở Service tương ứng: PropertyService, AppointmentService, ReviewService...
 */
public class Customer extends User {
    private static final long serialVersionUID = 1L;

    public Customer() {
        setRole(ROLE_CUSTOMER);
    }

    public long getCustomerId() {
        return getUserId();
    }
}
