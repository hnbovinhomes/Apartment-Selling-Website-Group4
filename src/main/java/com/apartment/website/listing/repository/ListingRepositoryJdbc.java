package com.apartment.website.listing.repository;

import com.apartment.website.config.Database;
import com.apartment.website.listing.entity.Listing;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Tin đăng trong PostgreSQL (bảng listings, JOIN users để lấy tên chủ căn hộ). */
public class ListingRepositoryJdbc implements ListingRepository {

    private static final String COLUMNS = "l.listing_id, l.listing_code, l.owner_id, l.property_id, l.listing_title, "
            + "l.asking_price, l.description, l.post_date, l.expiry_date, l.status, l.created_at, l.updated_at, "
            + "l.listing_type, l.moderation_status, l.reviewed_by, l.reviewed_at, l.moderation_reason, "
            + "u.full_name AS owner_name, u.phone AS owner_phone ";

    private static final String FROM = "FROM listings l "
            + "JOIN users u ON u.user_id = l.owner_id ";

    @Override
    public List<Listing> findByOwner(long ownerId) {
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE l.owner_id = ? "
                + "ORDER BY l.post_date DESC, l.listing_id DESC";

        List<Listing> listings = new ArrayList<Listing>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, ownerId);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        listings.add(mapListing(rs));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return listings;
    }

    @Override
    public List<Listing> findAll(String keyword) {
        String sql = "SELECT " + COLUMNS + FROM;
        boolean hasKeyword = keyword != null && !keyword.trim().isEmpty();
        if (hasKeyword) {
            // tìm theo tiêu đề tin, mã tin, tên hoặc SĐT chủ căn hộ
            sql = sql + "WHERE l.listing_title ILIKE ? OR l.listing_code ILIKE ? OR u.full_name ILIKE ? OR u.phone LIKE ? ";
        }
        sql = sql + "ORDER BY l.post_date DESC, l.listing_id DESC";

        List<Listing> listings = new ArrayList<Listing>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                if (hasKeyword) {
                    String pattern = "%" + keyword.trim() + "%";
                    statement.setString(1, pattern);
                    statement.setString(2, pattern);
                    statement.setString(3, pattern);
                    statement.setString(4, pattern);
                }
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        listings.add(mapListing(rs));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return listings;
    }

    @Override
    public Listing findById(long listingId) {
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE l.listing_id = ?";

        Listing listing = null;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, listingId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        listing = mapListing(rs);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return listing;
    }

    @Override
    public boolean deleteByAdmin(Listing listing, long adminId, String reason) {
        long propertyId = listing.getPropertyId();
        String reasonText = "";
        if (reason != null) {
            reasonText = " Lý do: " + reason;
        }

        // Các bảng có khóa ngoại tới properties nhưng KHÔNG có ON DELETE CASCADE -> phải xóa trước.
        // (property_images, favorites có ON DELETE CASCADE nên tự xóa theo properties)
        String notifyCustomersSql = "INSERT INTO notifications (user_id, title, message, notification_type, related_type, related_id) "
                + "SELECT DISTINCT v.customer_id, ?, ?, 'SYSTEM', 'PROPERTY', ? "
                + "FROM property_viewings v "
                + "WHERE v.property_id = ? AND v.status IN ('Chờ xác nhận', 'Đã xác nhận')";
        String deleteViewingNotificationsSql = "DELETE FROM notifications "
                + "WHERE related_type = 'VIEWING' "
                + "AND related_id IN (SELECT viewing_id FROM property_viewings WHERE property_id = ?)";
        String deleteReportActionsSql = "DELETE FROM report_actions "
                + "WHERE report_id IN (SELECT report_id FROM property_reports WHERE property_id = ?)";
        String deleteReportsSql = "DELETE FROM property_reports WHERE property_id = ?";
        String deleteReviewsSql = "DELETE FROM reviews WHERE property_id = ?";
        String deleteViewingsSql = "DELETE FROM property_viewings WHERE property_id = ?";
        String deleteListingsSql = "DELETE FROM listings WHERE property_id = ?";
        String deletePropertySql = "DELETE FROM properties WHERE property_id = ?";
        String notifyOwnerSql = "INSERT INTO notifications (user_id, title, message, notification_type, related_type, related_id) "
                + "VALUES (?, ?, ?, 'SYSTEM', 'PROPERTY', ?)";
        String logSql = "INSERT INTO admin_activity_logs (admin_id, action_type, target_type, target_id, description) "
                + "VALUES (?, 'DELETE_PROPERTY', 'PROPERTY', ?, ?)";

        try (Connection connection = Database.getConnection()) {
            // tất cả các bước trong 1 transaction: lỗi ở bước nào thì không xóa gì cả
            connection.setAutoCommit(false);

            // 1. Báo cho khách đang có lịch hẹn xem căn này
            try (PreparedStatement statement = connection.prepareStatement(notifyCustomersSql)) {
                statement.setString(1, "Lịch hẹn bị hủy do căn hộ bị gỡ");
                statement.setString(2, "Căn \"" + listing.getListingTitle()
                        + "\" đã bị quản trị viên gỡ khỏi hệ thống nên lịch xem của bạn bị hủy.");
                statement.setLong(3, propertyId);
                statement.setLong(4, propertyId);
                statement.executeUpdate();
            }

            // 2. Xóa dữ liệu phụ thuộc vào căn rao bán
            executeWithId(connection, deleteViewingNotificationsSql, propertyId);
            executeWithId(connection, deleteReportActionsSql, propertyId);
            executeWithId(connection, deleteReportsSql, propertyId);
            executeWithId(connection, deleteReviewsSql, propertyId);
            executeWithId(connection, deleteViewingsSql, propertyId);
            executeWithId(connection, deleteListingsSql, propertyId);

            // 3. Xóa căn rao bán (ảnh, yêu thích tự xóa theo nhờ ON DELETE CASCADE).
            //    Dòng apartments (căn hộ vật lý của chủ) vẫn giữ để chủ đăng lại sau khi sửa mô tả.
            int deleted = executeWithId(connection, deletePropertySql, propertyId);
            if (deleted != 1) {
                connection.rollback();
                return false;
            }

            // 4. Báo cho chủ căn hộ
            try (PreparedStatement statement = connection.prepareStatement(notifyOwnerSql)) {
                statement.setLong(1, listing.getOwnerId());
                statement.setString(2, "Tin đăng đã bị gỡ");
                statement.setString(3, "Tin \"" + listing.getListingTitle() + "\" (" + listing.getListingCode()
                        + ") bị quản trị viên gỡ vì thông tin không đúng mô tả." + reasonText);
                statement.setLong(4, propertyId);
                statement.executeUpdate();
            }

            // 5. Ghi nhật ký thao tác của admin (bảng admin_activity_logs)
            try (PreparedStatement statement = connection.prepareStatement(logSql)) {
                statement.setLong(1, adminId);
                statement.setLong(2, propertyId);
                statement.setString(3, "Xóa tin " + listing.getListingCode() + " - " + listing.getListingTitle() + "." + reasonText);
                statement.executeUpdate();
            }

            connection.commit();
            return true;
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    /** Chạy câu DELETE có 1 tham số id, trả về số dòng bị xóa. */
    private static int executeWithId(Connection connection, String sql, long id) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            return statement.executeUpdate();
        }
    }

    /** Đọc 1 dòng ResultSet (theo COLUMNS ở trên) thành 1 object Listing. */
    private static Listing mapListing(ResultSet rs) throws SQLException {
        Listing listing = new Listing();
        listing.setListingId(rs.getLong("listing_id"));
        listing.setListingCode(rs.getString("listing_code"));
        listing.setOwnerId(rs.getLong("owner_id"));
        listing.setPropertyId(rs.getLong("property_id"));
        listing.setListingTitle(rs.getString("listing_title"));
        listing.setAskingPrice(rs.getBigDecimal("asking_price"));
        listing.setDescription(rs.getString("description"));
        listing.setPostDate(rs.getObject("post_date", LocalDateTime.class));
        listing.setExpiryDate(rs.getObject("expiry_date", LocalDateTime.class));
        listing.setStatus(rs.getString("status"));
        listing.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
        listing.setUpdatedAt(rs.getObject("updated_at", LocalDateTime.class));
        listing.setListingType(rs.getString("listing_type"));
        listing.setModerationStatus(rs.getString("moderation_status"));
        long reviewedBy = rs.getLong("reviewed_by");
        if (rs.wasNull()) {
            listing.setReviewedBy(null);
        } else {
            listing.setReviewedBy(reviewedBy);
        }
        listing.setReviewedAt(rs.getObject("reviewed_at", LocalDateTime.class));
        listing.setModerationReason(rs.getString("moderation_reason"));
        listing.setOwnerName(rs.getString("owner_name"));
        listing.setOwnerPhone(rs.getString("owner_phone"));
        return listing;
    }
}
