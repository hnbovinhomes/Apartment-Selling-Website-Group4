package com.apartment.website.listing.service;

import com.apartment.website.common.exception.ListingException;
import com.apartment.website.listing.entity.Listing;
import com.apartment.website.listing.repository.ListingRepository;
import com.apartment.website.user.entity.User;

import java.util.List;

/**
 * Nghiệp vụ tin đăng.
 *  - Chủ căn hộ: manageListings() của diagram -> myListings()
 *  - Admin: rà soát mọi tin -> allListings(), xóa tin sai mô tả -> deleteByAdmin()
 */
public class ListingService {
    private static final int MAX_REASON = 500;

    private final ListingRepository repository;

    public ListingService(ListingRepository repository) {
        this.repository = repository;
    }

    /** Tin đăng của chủ căn hộ đang đăng nhập. */
    public List<Listing> myListings(long ownerId) {
        return repository.findByOwner(ownerId);
    }

    /** Admin xem tất cả tin đăng, có thể lọc theo từ khóa. */
    public List<Listing> allListings(String keyword) {
        return repository.findAll(keyword);
    }

    /** Admin xóa 1 tin đăng (và căn rao bán của nó). Trả về câu thông báo thành công, sai thì ném ListingException. */
    public String deleteByAdmin(long listingId, User admin, String reasonText) {
        if (admin == null || !admin.isAdmin()) {
            throw new ListingException("Chỉ quản trị viên mới xóa được tin đăng.");
        }
        String reason = "";
        if (reasonText != null) {
            reason = reasonText.trim();
        }
        if (reason.isEmpty()) {
            throw new ListingException("Vui lòng nhập lý do xóa để báo cho chủ căn hộ.");
        }
        if (reason.length() > MAX_REASON) {
            throw new ListingException("Lý do tối đa " + MAX_REASON + " ký tự.");
        }

        Listing listing = repository.findById(listingId);
        if (listing == null) {
            throw new ListingException("Tin đăng không còn tồn tại (có thể đã bị xóa).");
        }
        boolean deleted = repository.deleteByAdmin(listing, admin.getUserId(), reason);
        if (!deleted) {
            throw new ListingException("Không xóa được tin đăng, vui lòng thử lại.");
        }
        return "Đã xóa tin " + listing.getListingCode() + " và báo cho chủ căn hộ " + listing.getOwnerName() + ".";
    }
}
