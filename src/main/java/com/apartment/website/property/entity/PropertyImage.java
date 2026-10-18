package com.apartment.website.property.entity;

import java.time.LocalDateTime;

/** JavaBean: ảnh của tin rao (bảng property_images). Diagram: Property 1 --- 0..* PropertyImage; isPrimary = is_thumbnail. */
public class PropertyImage {
    private long imageId;
    private long propertyId;
    private String imageUrl;
    private boolean primary;
    private LocalDateTime uploadedAt;

    public PropertyImage() {
    }

    public long getImageId() {
        return imageId;
    }

    public void setImageId(long imageId) {
        this.imageId = imageId;
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    /** Chuẩn hóa đường dẫn ảnh (thêm dấu / ở đầu, không có ảnh thì dùng ảnh mặc định). */
    public void setImageUrl(String imageUrl) {
        this.imageUrl = Property.imageUrl(imageUrl);
    }

    public boolean isPrimary() {
        return primary;
    }

    public void setPrimary(boolean primary) {
        this.primary = primary;
    }

    public LocalDateTime getUploadedAt() {
        return uploadedAt;
    }

    public void setUploadedAt(LocalDateTime uploadedAt) {
        this.uploadedAt = uploadedAt;
    }
}
