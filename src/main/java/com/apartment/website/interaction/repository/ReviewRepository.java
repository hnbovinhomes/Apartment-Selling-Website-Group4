package com.apartment.website.interaction.repository;

import com.apartment.website.interaction.entity.Review;

import java.util.List;

public interface ReviewRepository {
    /** Các đánh giá đang hiện (status = VISIBLE) của 1 căn, mới nhất trước. */
    List<Review> findByProperty(long propertyId);

    /** Lưu đánh giá. Khách đã đánh giá căn này rồi thì cập nhật. Trả về true nếu là đánh giá mới. */
    boolean save(long customerId, long propertyId, int rating, String comment);
}
