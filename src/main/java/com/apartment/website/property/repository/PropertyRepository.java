package com.apartment.website.property.repository;

import com.apartment.website.property.dto.PageResult;
import com.apartment.website.property.dto.PropertyFilter;
import com.apartment.website.property.entity.Property;
import com.apartment.website.user.entity.Owner;

import java.util.List;

public interface PropertyRepository {
    PageResult<Property> search(PropertyFilter filter, int page, int size);

    /** Trả về null nếu không có căn với id này. */
    Property findById(long id);

    List<String> districts();

    /** Căn tương tự căn p (cùng loại Bán/Thuê, giá & diện tích gần). sameDistrict = true: cùng quận, false: quận khác. */
    List<Property> similar(Property p, boolean sameDistrict, int limit);

    /** Chủ căn hộ (qua apartments.owner_id -> owners -> users). Không có thì null. */
    Owner ownerOf(long propertyId);

    /** Số tin đang đăng (status = ACTIVE) của 1 chủ căn hộ. */
    int activeListingCount(long ownerId);
}
