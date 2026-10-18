package com.apartment.website.user.entity;

/**
 * Chủ căn hộ (bảng owners, owner_id = users.user_id) -> kế thừa User.
 * Số điện thoại nằm ở users.phone (lớp cha); owners chỉ có thêm tax_code và identity_verified.
 * createListing() / manageListings() của diagram nằm ở ListingService.
 */
public class Owner extends User {
    private static final long serialVersionUID = 1L;

    private String taxCode;
    private boolean identityVerified;

    public Owner() {
        setRole(ROLE_OWNER);
    }

    public long getOwnerId() {
        return getUserId();
    }

    public String getTaxCode() {
        return taxCode;
    }

    public void setTaxCode(String taxCode) {
        this.taxCode = taxCode;
    }

    public boolean isIdentityVerified() {
        return identityVerified;
    }

    public void setIdentityVerified(boolean identityVerified) {
        this.identityVerified = identityVerified;
    }
}
