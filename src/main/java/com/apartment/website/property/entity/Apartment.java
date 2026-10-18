package com.apartment.website.property.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** JavaBean: căn hộ vật lý trong một tòa nhà (bảng apartments). Diagram: Apartment thuộc 1 Building và 1 Owner, Property rao bán 1 Apartment. */
public class Apartment {
    private long apartmentId;
    private Building building;
    private long ownerId;
    private String apartmentCode;
    private int floorNumber;
    private String roomNumber;
    private BigDecimal area;
    private int bedrooms;
    private int bathrooms;
    private BigDecimal balconyArea;
    private String direction;
    private String viewType;
    private String legalStatus;
    private String status;
    private LocalDateTime createdAt;

    public Apartment() {
    }

    public long getApartmentId() {
        return apartmentId;
    }

    public void setApartmentId(long apartmentId) {
        this.apartmentId = apartmentId;
    }

    public Building getBuilding() {
        return building;
    }

    public void setBuilding(Building building) {
        this.building = building;
    }

    /** Cột apartments.owner_id: chủ của căn hộ. */
    public long getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(long ownerId) {
        this.ownerId = ownerId;
    }

    public String getApartmentCode() {
        return apartmentCode;
    }

    public void setApartmentCode(String apartmentCode) {
        this.apartmentCode = apartmentCode;
    }

    public int getFloorNumber() {
        return floorNumber;
    }

    public void setFloorNumber(int floorNumber) {
        this.floorNumber = floorNumber;
    }

    public String getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(String roomNumber) {
        this.roomNumber = roomNumber;
    }

    public BigDecimal getArea() {
        return area;
    }

    public void setArea(BigDecimal area) {
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

    public BigDecimal getBalconyArea() {
        return balconyArea;
    }

    public void setBalconyArea(BigDecimal balconyArea) {
        this.balconyArea = balconyArea;
    }

    public String getDirection() {
        return direction;
    }

    public void setDirection(String direction) {
        this.direction = direction;
    }

    public String getViewType() {
        return viewType;
    }

    public void setViewType(String viewType) {
        this.viewType = viewType;
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

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    /** getDetails() trong diagram. */
    public String getDetails() {
        String areaText = "";
        if (area != null) {
            areaText = area.stripTrailingZeros().toPlainString();
        }
        return "Căn " + apartmentCode + " - tầng " + floorNumber + ", " + areaText
                + " m², " + bedrooms + " PN, " + bathrooms + " WC";
    }
}
