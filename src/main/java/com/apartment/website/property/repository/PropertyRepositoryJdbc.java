package com.apartment.website.property.repository;

import com.apartment.website.config.Database;
import com.apartment.website.property.dto.PageResult;
import com.apartment.website.property.dto.PropertyFilter;
import com.apartment.website.property.entity.Property;
import com.apartment.website.user.entity.Owner;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Lấy dữ liệu thật từ PostgreSQL bằng JDBC. */
public class PropertyRepositoryJdbc implements PropertyRepository {

    /** Các cột cần lấy cho 1 căn hộ (dùng chung cho mọi câu SELECT bên dưới). */
    private static final String COLUMNS = "p.property_id, p.title, p.price, p.price_per_m2, p.description, p.address, "
            + "b.building_name, b.district, b.city, a.floor_number, a.area, a.bedrooms, a.bathrooms, "
            + "a.direction, a.legal_status, p.status, p.listing_type, "
            + "(SELECT i.image_url FROM property_images i "
            + "WHERE i.property_id = p.property_id "
            + "ORDER BY i.is_thumbnail DESC, i.image_id "
            + "LIMIT 1) AS thumb ";

    private static final String FROM = "FROM properties p "
            + "JOIN apartments a ON a.apartment_id = p.apartment_id "
            + "JOIN buildings b ON b.building_id = a.building_id ";

    @Override
    public PageResult<Property> search(PropertyFilter filter, int page, int size) {
        // Ghép điều kiện WHERE theo những ô lọc người dùng đã chọn.
        // Giá trị không ghép thẳng vào SQL mà để dấu ? rồi gán sau (chống SQL Injection).
        String where = "WHERE p.status = 'AVAILABLE' AND p.listing_type = ? ";
        List<Object> parameters = new ArrayList<Object>();
        parameters.add(filter.getListingType());

        if (filter.hasKeyword()) {
            where = where + "AND (p.title ILIKE ? OR b.building_name ILIKE ? OR b.address ILIKE ?) ";
            String keyword = "%" + filter.getKeyword().trim() + "%";
            parameters.add(keyword);
            parameters.add(keyword);
            parameters.add(keyword);
        }
        if (filter.hasDistrict()) {
            where = where + "AND b.district = ? ";
            parameters.add(filter.getDistrict());
        }
        if (filter.getBedrooms() != null) {
            // chọn "3+" thì lấy từ 3 phòng ngủ trở lên
            if (filter.getBedrooms() >= 3) {
                where = where + "AND a.bedrooms >= ? ";
            } else {
                where = where + "AND a.bedrooms = ? ";
            }
            parameters.add(filter.getBedrooms());
        }
        if (filter.getMinPrice() != null) {
            where = where + "AND p.price >= ? ";
            parameters.add(filter.getMinPrice());
        }
        if (filter.getMaxPrice() != null) {
            where = where + "AND p.price <= ? ";
            parameters.add(filter.getMaxPrice());
        }

        String countSql = "SELECT COUNT(*) " + FROM + where;
        String pageSql = "SELECT " + COLUMNS + FROM + where
                + "ORDER BY p.created_at DESC "
                + "LIMIT ? OFFSET ?";

        long total = 0;
        List<Property> items = new ArrayList<Property>();

        try (Connection connection = Database.getConnection()) {
            // Câu 1: đếm tổng số căn khớp bộ lọc (để vẽ phân trang)
            try (PreparedStatement statement = connection.prepareStatement(countSql)) {
                for (int i = 0; i < parameters.size(); i++) {
                    statement.setObject(i + 1, parameters.get(i));
                }
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        total = rs.getLong(1);
                    }
                }
            }

            // Câu 2: lấy đúng các căn của trang đang xem
            try (PreparedStatement statement = connection.prepareStatement(pageSql)) {
                int index = 1;
                for (int i = 0; i < parameters.size(); i++) {
                    statement.setObject(index, parameters.get(i));
                    index++;
                }
                statement.setInt(index, size);
                index++;
                statement.setInt(index, (page - 1) * size);

                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        Property property = mapProperty(rs, new ArrayList<String>());
                        items.add(property);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        PageResult<Property> result = new PageResult<Property>();
        result.setItems(items);
        result.setTotal(total);
        result.setPage(page);
        result.setSize(size);
        return result;
    }

    @Override
    public Property findById(long id) {
        String imageSql = "SELECT image_url "
                + "FROM property_images "
                + "WHERE property_id = ? "
                + "ORDER BY is_thumbnail DESC, image_id";
        String propertySql = "SELECT " + COLUMNS + FROM
                + "WHERE p.property_id = ?";

        Property property = null;
        try (Connection connection = Database.getConnection()) {
            // Lấy tất cả ảnh của căn (ảnh đại diện đứng đầu)
            List<String> images = new ArrayList<String>();
            try (PreparedStatement statement = connection.prepareStatement(imageSql)) {
                statement.setLong(1, id);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        images.add(Property.imageUrl(rs.getString("image_url")));
                    }
                }
            }

            // Lấy thông tin căn
            try (PreparedStatement statement = connection.prepareStatement(propertySql)) {
                statement.setLong(1, id);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        property = mapProperty(rs, images);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return property;
    }

    @Override
    public List<String> districts() {
        String sql = "SELECT DISTINCT district "
                + "FROM buildings "
                + "WHERE district IS NOT NULL "
                + "ORDER BY district";

        List<String> list = new ArrayList<String>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        list.add(rs.getString("district"));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return list;
    }

    @Override
    public List<Property> similar(Property p, boolean sameDistrict, int limit) {
        // Lọc cứng theo quận (= hoặc <>), rồi chấm điểm: giá lệch <= 30% được +2, diện tích lệch <= 20% được +1.
        // Căn giống nhất lên đầu, hòa điểm thì căn có giá gần hơn đứng trước.
        String districtCondition;
        if (sameDistrict) {
            districtCondition = "AND b.district = ? ";
        } else {
            districtCondition = "AND b.district <> ? ";
        }
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE p.status = 'AVAILABLE' "
                + "AND p.listing_type = ? "
                + "AND p.property_id <> ? "
                + districtCondition
                + "ORDER BY (CASE WHEN p.price BETWEEN ? * 0.7 AND ? * 1.3 THEN 2 ELSE 0 END) "
                + "+ (CASE WHEN a.area BETWEEN ? * 0.8 AND ? * 1.2 THEN 1 ELSE 0 END) DESC, "
                + "ABS(p.price - ?), "
                + "p.created_at DESC "
                + "LIMIT ?";

        BigDecimal price = p.getPrice();
        if (price == null) {
            price = BigDecimal.ZERO;
        }
        BigDecimal area = new BigDecimal(p.getArea());

        List<Property> items = new ArrayList<Property>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setString(1, p.getListingType());
                statement.setLong(2, p.getPropertyId());
                statement.setString(3, p.getDistrict());
                statement.setBigDecimal(4, price);
                statement.setBigDecimal(5, price);
                statement.setBigDecimal(6, area);
                statement.setBigDecimal(7, area);
                statement.setBigDecimal(8, price);
                statement.setInt(9, limit);

                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        Property property = mapProperty(rs, new ArrayList<String>());
                        items.add(property);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return items;
    }

    @Override
    public Owner ownerOf(long propertyId) {
        // Chủ căn hộ: properties -> apartments.owner_id -> owners + users (số điện thoại ở users.phone)
        String sql = "SELECT u.user_id, u.username, u.email, u.role, u.created_at, u.is_active, "
                + "u.full_name, u.phone, o.tax_code, o.identity_verified "
                + "FROM properties p "
                + "JOIN apartments a ON a.apartment_id = p.apartment_id "
                + "JOIN owners o ON o.owner_id = a.owner_id "
                + "JOIN users u ON u.user_id = o.owner_id "
                + "WHERE p.property_id = ?";

        Owner owner = null;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, propertyId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        owner = new Owner();
                        owner.setUserId(rs.getLong("user_id"));
                        owner.setUsername(rs.getString("username"));
                        owner.setEmail(rs.getString("email"));
                        owner.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
                        owner.setActive(rs.getInt("is_active") == 1);
                        owner.setFullName(rs.getString("full_name"));
                        owner.setPhone(rs.getString("phone"));
                        owner.setTaxCode(rs.getString("tax_code"));
                        owner.setIdentityVerified(rs.getBoolean("identity_verified"));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return owner;
    }

    @Override
    public int activeListingCount(long ownerId) {
        String sql = "SELECT COUNT(*) "
                + "FROM listings "
                + "WHERE owner_id = ? AND status = 'ACTIVE'";

        int count = 0;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, ownerId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        count = rs.getInt(1);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return count;
    }

    /** Đọc 1 dòng ResultSet (theo COLUMNS ở trên) thành 1 object Property. */
    private static Property mapProperty(ResultSet rs, List<String> images) throws SQLException {
        Property property = new Property();
        property.setPropertyId(rs.getLong("property_id"));
        property.setTitle(rs.getString("title"));

        BigDecimal price = rs.getBigDecimal("price");
        property.setPrice(price);
        property.setPriceText(Property.priceText(price));
        BigDecimal pricePerM2 = rs.getBigDecimal("price_per_m2");
        if (pricePerM2 != null) {
            property.setPricePerM2Text(Property.priceText(pricePerM2));
        } else {
            property.setPricePerM2Text("");
        }

        property.setDescription(emptyIfNull(rs.getString("description")));
        property.setAddress(emptyIfNull(rs.getString("address")));
        property.setBuildingName(emptyIfNull(rs.getString("building_name")));
        property.setDistrict(emptyIfNull(rs.getString("district")));
        property.setCity(emptyIfNull(rs.getString("city")));
        property.setFloor(rs.getInt("floor_number"));
        // NUMERIC 75.50 -> "75.5"
        property.setArea(rs.getBigDecimal("area").stripTrailingZeros().toPlainString());
        property.setBedrooms(rs.getInt("bedrooms"));
        property.setBathrooms(rs.getInt("bathrooms"));
        property.setDirection(emptyIfNull(rs.getString("direction")));
        property.setLegalStatus(emptyIfNull(rs.getString("legal_status")));
        property.setStatus(rs.getString("status"));
        property.setThumbnailUrl(Property.imageUrl(rs.getString("thumb")));
        property.setImageUrls(images);
        property.setListingType(rs.getString("listing_type"));
        return property;
    }

    private static String emptyIfNull(String value) {
        if (value == null) {
            return "";
        }
        return value;
    }
}
