package com.apartment.website.interaction.entity;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Đánh giá của khách cho 1 căn (bảng reviews). Diagram: Customer 1 --writes-- 0..* Review 0..* --receives-- 1 Property.
 * DB ràng buộc: rating 1..5, mỗi khách chỉ có 1 đánh giá / căn (uq_reviews_customer_property),
 * customer_id phải là tài khoản CUSTOMER đang hoạt động (trigger trg_check_review_customer).
 * reviewerName không phải cột của reviews: lấy từ users.full_name khi JOIN.
 */
public class Review {
    public static final int MIN_RATING = 1;
    public static final int MAX_RATING = 5;
    public static final int MAX_COMMENT = 1000;
    public static final String VISIBLE = "VISIBLE";
    public static final String HIDDEN = "HIDDEN";
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private long reviewId;
    private long customerId;
    private long propertyId;
    private int rating;
    private String comment;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // lấy thêm khi JOIN users
    private String reviewerName;

    public Review() {
    }

    public long getReviewId() {
        return reviewId;
    }

    public void setReviewId(long reviewId) {
        this.reviewId = reviewId;
    }

    public long getCustomerId() {
        return customerId;
    }

    public void setCustomerId(long customerId) {
        this.customerId = customerId;
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public int getRating() {
        return rating;
    }

    public void setRating(int rating) {
        this.rating = rating;
    }

    public String getComment() {
        return comment;
    }

    public void setComment(String comment) {
        this.comment = comment;
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

    public String getReviewerName() {
        return reviewerName;
    }

    public void setReviewerName(String reviewerName) {
        this.reviewerName = reviewerName;
    }

    /** JSP: ${r.dateText} -> ngày sửa gần nhất, "14/10/2026" */
    public String getDateText() {
        LocalDateTime date = updatedAt;
        if (date == null) {
            date = createdAt;
        }
        if (date == null) {
            return "";
        }
        return date.format(DATE_FORMAT);
    }

    /** JSP: ${r.stars} -> "★★★★☆" */
    public String getStars() {
        StringBuilder stars = new StringBuilder();
        for (int i = 1; i <= MAX_RATING; i++) {
            if (i <= rating) {
                stars.append("★");
            } else {
                stars.append("☆");
            }
        }
        return stars.toString();
    }

    /** JSP: ${r.initial} -> chữ cái đầu của tên cuối, làm avatar. */
    public String getInitial() {
        if (reviewerName == null || reviewerName.trim().isEmpty()) {
            return "?";
        }
        String[] words = reviewerName.trim().split("\\s+");
        String lastWord = words[words.length - 1];
        return lastWord.substring(0, 1).toUpperCase();
    }
}
