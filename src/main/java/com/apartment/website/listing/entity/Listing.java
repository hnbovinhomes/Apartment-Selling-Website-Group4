package com.apartment.website.listing.entity;

import com.apartment.website.property.entity.Property;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Tin đăng của chủ căn hộ (bảng listings). Diagram: Owner 1 --- 0..* Listing, Listing --- 1 Property.
 * Web đăng tin không cần duyệt: tin đăng xong là hiện luôn (moderation_status luôn = PUBLISHED).
 * Admin rà soát và có thể xóa tin sai mô tả. status: ACTIVE (đang đăng), EXPIRED, SOLD...
 * ownerName, ownerPhone không phải cột của listings: lấy thêm khi JOIN users (trang admin).
 */
public class Listing {
    public static final String ACTIVE = "ACTIVE";
    public static final String EXPIRED = "EXPIRED";

    public static final String SOLD = "SOLD";
    public static final String PUBLISHED = "PUBLISHED";

    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private long listingId;
    private String listingCode;
    private long ownerId;
    private long propertyId;
    private String listingTitle;
    private BigDecimal askingPrice;
    private String description;
    private LocalDateTime postDate;
    private LocalDateTime expiryDate;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private String listingType;
    private String moderationStatus;
    private Long reviewedBy;
    private LocalDateTime reviewedAt;
    private String moderationReason;

    // lấy thêm khi JOIN users (trang Quản lý tin của admin)
    private String ownerName;
    private String ownerPhone;

    public Listing() {
    }

    public long getListingId() {
        return listingId;
    }

    public void setListingId(long listingId) {
        this.listingId = listingId;
    }

    public String getListingCode() {
        return listingCode;
    }

    public void setListingCode(String listingCode) {
        this.listingCode = listingCode;
    }

    public long getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(long ownerId) {
        this.ownerId = ownerId;
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public String getListingTitle() {
        return listingTitle;
    }

    public void setListingTitle(String listingTitle) {
        this.listingTitle = listingTitle;
    }

    public BigDecimal getAskingPrice() {
        return askingPrice;
    }

    public void setAskingPrice(BigDecimal askingPrice) {
        this.askingPrice = askingPrice;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public LocalDateTime getPostDate() {
        return postDate;
    }

    public void setPostDate(LocalDateTime postDate) {
        this.postDate = postDate;
    }

    public LocalDateTime getExpiryDate() {
        return expiryDate;
    }

    public void setExpiryDate(LocalDateTime expiryDate) {
        this.expiryDate = expiryDate;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public String getListingType() {
        return listingType;
    }

    public void setListingType(String listingType) {
        this.listingType = listingType;
    }

    public String getModerationStatus() {
        return moderationStatus;
    }

    public void setModerationStatus(String moderationStatus) {
        this.moderationStatus = moderationStatus;
    }

    public Long getReviewedBy() {
        return reviewedBy;
    }

    public void setReviewedBy(Long reviewedBy) {
        this.reviewedBy = reviewedBy;
    }

    public LocalDateTime getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(LocalDateTime reviewedAt) {
        this.reviewedAt = reviewedAt;
    }

    public String getModerationReason() {
        return moderationReason;
    }

    public void setModerationReason(String moderationReason) {
        this.moderationReason = moderationReason;
    }

    public String getOwnerName() {
        return ownerName;
    }

    public void setOwnerName(String ownerName) {
        this.ownerName = ownerName;
    }

    public String getOwnerPhone() {
        return ownerPhone;
    }

    public void setOwnerPhone(String ownerPhone) {
        this.ownerPhone = ownerPhone;
    }

    // ===== các getter tự tính cho JSP =====

    /** JSP: ${l.rent} */
    public boolean isRent() {
        return "RENT".equals(listingType);
    }

    /** 3500000000 -> "3.5 Tỷ" (căn thuê thêm "/tháng") */
    public String getPriceText() {
        String text = Property.priceText(askingPrice);
        if (isRent()) {
            return text + "/tháng";
        }
        return text;
    }

    /** JSP: ${l.postDateText} -> "11/10/2026" */
    public String getPostDateText() {
        if (postDate == null) {
            return "";
        }
        return postDate.format(DATE_FORMAT);
    }

    /** Trạng thái tin bằng tiếng Việt: ACTIVE -> "Đang đăng". */
    public String getStatusText() {
        if (ACTIVE.equals(status)) {
            return "Đang đăng";
        }
        if (SOLD.equals(status)) {
            return "Đã bán";
        }
        if (EXPIRED.equals(status)) {
            return "Hết hạn";
        }
        return status;
    }

    /** Tin còn hiệu lực: đang ACTIVE và chưa quá hạn. */
    public boolean isActive() {
        if (!ACTIVE.equals(status)) {
            return false;
        }
        if (expiryDate == null) {
            return true;
        }
        return expiryDate.isAfter(LocalDateTime.now());
    }
}
