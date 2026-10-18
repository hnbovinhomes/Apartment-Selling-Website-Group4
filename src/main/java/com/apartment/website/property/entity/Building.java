package com.apartment.website.property.entity;

import java.time.LocalDateTime;

/** JavaBean: tòa nhà / chung cư (bảng buildings). Diagram: Building 1 --- 1..* Apartment. */
public class Building {
    private long buildingId;
    private String buildingCode;
    private String buildingName;
    private String address;
    private String ward;
    private String district;
    private String city;
    private int totalFloors;
    private int totalApartments;
    private Integer yearBuilt;
    private String description;
    private String status;
    private LocalDateTime createdAt;
    private long apartmentsInDatabase;

    public Building() {
    }

    public long getBuildingId() {
        return buildingId;
    }

    public void setBuildingId(long buildingId) {
        this.buildingId = buildingId;
    }

    public String getBuildingCode() {
        return buildingCode;
    }

    public void setBuildingCode(String buildingCode) {
        this.buildingCode = buildingCode;
    }

    public String getBuildingName() {
        return buildingName;
    }

    public void setBuildingName(String buildingName) {
        this.buildingName = buildingName;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getWard() {
        return ward;
    }

    public void setWard(String ward) {
        this.ward = ward;
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

    public int getTotalFloors() {
        return totalFloors;
    }

    public void setTotalFloors(int totalFloors) {
        this.totalFloors = totalFloors;
    }

    public int getTotalApartments() {
        return totalApartments;
    }

    public void setTotalApartments(int totalApartments) {
        this.totalApartments = totalApartments;
    }

    public Integer getYearBuilt() {
        return yearBuilt;
    }

    public void setYearBuilt(Integer yearBuilt) {
        this.yearBuilt = yearBuilt;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
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

    /** Cột apartments_in_database: số căn của tòa đã có trong hệ thống. */
    public long getApartmentsInDatabase() {
        return apartmentsInDatabase;
    }

    public void setApartmentsInDatabase(long apartmentsInDatabase) {
        this.apartmentsInDatabase = apartmentsInDatabase;
    }

    /** getDetails() trong diagram. */
    public String getDetails() {
        return buildingName + " - " + address + ", " + district + ", " + city + " (" + totalFloors + " tầng)";
    }
}
