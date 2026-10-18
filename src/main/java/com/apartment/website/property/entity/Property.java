package com.apartment.website.property.entity;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * JavaBean: 1 căn hộ đang rao bán (gom từ properties + apartments + buildings + property_images).
 * PropertyRepositoryJdbc tạo bằng new Property() rồi gọi setXxx(rs.getXxx("cot")).
 * JSP đọc qua getter: ${it.title} -> getTitle(), ${property.priceText} -> getPriceText()...
 */
public class Property {
    public static final String NO_IMAGE = "/images/apartment-sample.jpg";

    private long propertyId;
    private String title;
    private BigDecimal price;
    private String priceText;
    private String pricePerM2Text;
    private String description;
    private String address;
    private String buildingName;
    private String district;
    private String city;
    private int floor;
    private String area;
    private int bedrooms;
    private int bathrooms;
    private String direction;
    private String legalStatus;
    private String status;
    private String thumbnailUrl;
    private List<String> imageUrls = new ArrayList<String>();
    private String listingType = "SALE";

    public Property() {
    }

    public long getPropertyId() {
        return propertyId;
    }

    public void setPropertyId(long propertyId) {
        this.propertyId = propertyId;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    /** Căn thuê thêm "/tháng" phía sau giá. */
    public String getPriceText() {
        if (isRent()) {
            return priceText + "/tháng";
        }
        return priceText;
    }

    public void setPriceText(String priceText) {
        this.priceText = priceText;
    }

    public String getPricePerM2Text() {
        return pricePerM2Text;
    }

    public void setPricePerM2Text(String pricePerM2Text) {
        this.pricePerM2Text = pricePerM2Text;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getBuildingName() {
        return buildingName;
    }

    public void setBuildingName(String buildingName) {
        this.buildingName = buildingName;
    }

    public String getDistrict() {
        return district;
    }

    public void setDistrict(String district) {
        this.district = district;
    }

    public String getCity() {
        return city;
    }

    public void setCity(String city) {
        this.city = city;
    }

    /** Cột apartments.floor_number. */
    public int getFloor() {
        return floor;
    }

    public void setFloor(int floor) {
        this.floor = floor;
    }

    public String getArea() {
        return area;
    }

    public void setArea(String area) {
        this.area = area;
    }

    public int getBedrooms() {
        return bedrooms;
    }

    public void setBedrooms(int bedrooms) {
        this.bedrooms = bedrooms;
    }

    public int getBathrooms() {
        return bathrooms;
    }

    public void setBathrooms(int bathrooms) {
        this.bathrooms = bathrooms;
    }

    public String getDirection() {
        return direction;
    }

    public void setDirection(String direction) {
        this.direction = direction;
    }

    public String getLegalStatus() {
        return legalStatus;
    }

    public void setLegalStatus(String legalStatus) {
        this.legalStatus = legalStatus;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getThumbnailUrl() {
        return thumbnailUrl;
    }

    public void setThumbnailUrl(String thumbnailUrl) {
        this.thumbnailUrl = thumbnailUrl;
    }

    public List<String> getImageUrls() {
        return imageUrls;
    }

    public void setImageUrls(List<String> imageUrls) {
        this.imageUrls = imageUrls;
    }

    /** "SALE" (bán) hoặc "RENT" (cho thuê). */
    public String getListingType() {
        return listingType;
    }

    public void setListingType(String listingType) {
        if (listingType == null) {
            this.listingType = "SALE";
        } else {
            this.listingType = listingType;
        }
    }

    /** JSP đọc là ${property.rent} */
    public boolean isRent() {
        return "RENT".equals(listingType);
    }

    /** Ảnh trong DB có thể là "images/a.jpg" (thiếu dấu /) -> chuẩn hóa để JSP ghép đúng đường dẫn. */
    public static String imageUrl(String url) {
        if (url == null || url.trim().isEmpty()) {
            return NO_IMAGE;
        }
        if (url.startsWith("/") || url.startsWith("http")) {
            return url;
        }
        return "/" + url;
    }

    /** 2800000000 -> "2.8 Tỷ", 35000000 -> "35 Triệu". */
    public static String priceText(BigDecimal price) {
        if (price == null) {
            return "";
        }
        double value = price.doubleValue();
        if (value >= 1e9) {
            String text = String.format(Locale.US, "%.1f Tỷ", value / 1e9);
            // "3.0 Tỷ" -> "3 Tỷ"
            return text.replace(".0 ", " ");
        }
        return String.format(Locale.US, "%.0f Triệu", value / 1e6);
    }
}
