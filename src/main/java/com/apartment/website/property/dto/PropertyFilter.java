package com.apartment.website.property.dto;

import java.math.BigDecimal;

/** JavaBean: điều kiện lọc từ thanh lọc ở trang danh sách. type = "SALE" (mặc định) hoặc "RENT". */
public class PropertyFilter {
    private String keyword = "";
    private String district = "";
    private Integer bedrooms;
    private String price = "";
    private String type = "SALE";

    public PropertyFilter() {
    }

    public String getKeyword() {
        return keyword;
    }

    public void setKeyword(String keyword) {
        this.keyword = keyword;
    }

    public String getDistrict() {
        return district;
    }

    public void setDistrict(String district) {
        this.district = district;
    }

    public Integer getBedrooms() {
        return bedrooms;
    }

    public void setBedrooms(Integer bedrooms) {
        this.bedrooms = bedrooms;
    }

    public String getPrice() {
        return price;
    }

    public void setPrice(String price) {
        this.price = price;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public boolean hasKeyword() {
        return keyword != null && !keyword.trim().isEmpty();
    }

    public boolean hasDistrict() {
        return district != null && !district.trim().isEmpty();
    }

    public boolean isRent() {
        return "RENT".equalsIgnoreCase(type);
    }

    public String getListingType() {
        if (isRent()) {
            return "RENT";
        }
        return "SALE";
    }

    /** Giá thấp nhất. Các mức giá (2 tỷ, 4 tỷ) chỉ có nghĩa với căn BÁN; căn thuê tính theo tháng nên bỏ qua. */
    public BigDecimal getMinPrice() {
        if (isRent()) {
            return null;
        }
        if ("2to4".equals(price)) {
            return new BigDecimal("2000000000");
        }
        if ("over4".equals(price)) {
            return new BigDecimal("4000000000");
        }
        return null;
    }

    /** Giá cao nhất (null = không giới hạn). */
    public BigDecimal getMaxPrice() {
        if (isRent()) {
            return null;
        }
        if ("under2".equals(price)) {
            return new BigDecimal("2000000000");
        }
        if ("2to4".equals(price)) {
            return new BigDecimal("4000000000");
        }
        return null;
    }
}
