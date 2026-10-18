package com.apartment.website.interaction.entity;

import java.time.LocalDateTime;

/** Căn hộ người dùng đã lưu yêu thích (bảng favorites, UNIQUE user_id + property_id). */
public class Favorite {
    private long favoriteId;
    private long userId;
    private long propertyId;
    private LocalDateTime createdAt;

    public Favorite() {
    }

    public long getFavoriteId() {
        return favoriteId;
    }

    public void setFavoriteId(long favoriteId) {
        this.favoriteId = favoriteId;
    }

    public long getUserId() {
        return userId;
    }

    public void setUserId(long userId) {
        this.userId = userId;
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
