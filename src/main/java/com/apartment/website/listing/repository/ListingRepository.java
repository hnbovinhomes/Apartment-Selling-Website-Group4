package com.apartment.website.listing.repository;

import com.apartment.website.listing.entity.Listing;

import java.util.List;

public interface ListingRepository {
    /** Tất cả tin đăng của 1 chủ căn hộ, mới nhất trước (trang "Quản lý tin" của chủ căn hộ). */
    List<Listing> findByOwner(long ownerId);

    /** Tất cả tin đăng của mọi chủ căn hộ (trang "Quản lý tin" của admin). keyword rỗng = không lọc. */
    List<Listing> findAll(String keyword);

    /** Trả về null nếu không có. */
    Listing findById(long listingId);

    /**
     * Admin xóa căn hộ đăng sai mô tả: xóa tin đăng + căn rao bán (properties) cùng dữ liệu đi kèm,
     * gửi thông báo cho chủ căn hộ và khách có lịch hẹn, ghi nhật ký admin. Tất cả trong 1 transaction.
     * Trả về true nếu xóa được.
     */
    boolean deleteByAdmin(Listing listing, long adminId, String reason);
}
