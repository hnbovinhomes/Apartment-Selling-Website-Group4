package com.apartment.website.listing.dto;

/** JavaBean: 1 ô của form đăng tin (tên ô + giá trị) để trang post-result.jsp in lại. */
public class FormField {
    private String name;
    private String value;

    public FormField() {
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getValue() {
        return value;
    }

    public void setValue(String value) {
        this.value = value;
    }
}
