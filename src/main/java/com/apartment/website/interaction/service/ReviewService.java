package com.apartment.website.interaction.service;

import com.apartment.website.common.exception.ReviewException;
import com.apartment.website.interaction.dto.ReviewSummary;
import com.apartment.website.interaction.entity.Review;
import com.apartment.website.interaction.repository.ReviewRepository;
import com.apartment.website.user.entity.User;

import java.util.ArrayList;
import java.util.List;

/** Quy tắc đánh giá: kiểm tra dữ liệu form, tính điểm trung bình. writeReview() / update() trong diagram nằm ở đây. */
public class ReviewService {
    private final ReviewRepository repository;

    public ReviewService(ReviewRepository repository) {
        this.repository = repository;
    }

    public List<Review> reviews(long propertyId) {
        return repository.findByProperty(propertyId);
    }

    /** Điểm trung bình + số lượt theo từng mức sao (5 -> 1). */
    public ReviewSummary summary(List<Review> reviews) {
        // countByStar[5] = số lượt 5 sao, countByStar[4] = số lượt 4 sao...
        int[] countByStar = new int[Review.MAX_RATING + 1];
        int sum = 0;
        for (int i = 0; i < reviews.size(); i++) {
            int rating = reviews.get(i).getRating();
            countByStar[rating]++;
            sum = sum + rating;
        }
        int total = reviews.size();

        List<ReviewSummary.StarRow> rows = new ArrayList<ReviewSummary.StarRow>();
        for (int star = Review.MAX_RATING; star >= Review.MIN_RATING; star--) {
            int percent = 0;
            if (total > 0) {
                percent = Math.round(countByStar[star] * 100f / total);
            }
            ReviewSummary.StarRow row = new ReviewSummary.StarRow();
            row.setStar(star);
            row.setCount(countByStar[star]);
            row.setPercent(percent);
            rows.add(row);
        }

        double average = 0;
        if (total > 0) {
            average = (double) sum / total;
        }
        ReviewSummary summary = new ReviewSummary();
        summary.setAverage(average);
        summary.setCount(total);
        summary.setRows(rows);
        return summary;
    }

    /**
     * Khách đang đăng nhập gửi đánh giá. Trả về true nếu là đánh giá mới, false nếu sửa lại đánh giá cũ.
     * DB chỉ cho tài khoản CUSTOMER viết đánh giá (trigger trg_check_review_customer).
     */
    public boolean submit(long propertyId, User customer, String ratingText, String comment) {
        if (customer == null || !customer.isCustomer()) {
            throw new ReviewException("Chỉ tài khoản khách hàng mới gửi được đánh giá.");
        }

        // 1. Chuẩn hóa dữ liệu
        if (comment == null) {
            comment = "";
        }
        comment = comment.trim();
        int rating;
        try {
            rating = Integer.parseInt(ratingText);
        } catch (NumberFormatException e) {
            rating = 0;
        }

        // 2. Kiểm tra dữ liệu, sai thì báo lỗi bằng tiếng Việt
        if (rating < Review.MIN_RATING || rating > Review.MAX_RATING) {
            throw new ReviewException("Vui lòng chọn số sao từ 1 đến 5.");
        }
        if (comment.isEmpty()) {
            throw new ReviewException("Vui lòng nhập nhận xét.");
        }
        if (comment.length() > Review.MAX_COMMENT) {
            throw new ReviewException("Nhận xét tối đa " + Review.MAX_COMMENT + " ký tự.");
        }

        // 3. Lưu xuống DB
        return repository.save(customer.getUserId(), propertyId, rating, comment);
    }
}
