package com.apartment.website.appointment.repository;

import com.apartment.website.appointment.entity.PropertyViewing;
import com.apartment.website.common.exception.SlotTakenException;
import com.apartment.website.config.Database;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Lịch hẹn xem nhà trong PostgreSQL (bảng property_viewings). */
public class PropertyViewingRepositoryJdbc implements PropertyViewingRepository {
    /** Mã lỗi PostgreSQL khi vi phạm EXCLUDE constraint no_overlapping_viewings (2 lịch trùng giờ). */
    private static final String EXCLUSION_VIOLATION = "23P01";

    /** Các trạng thái đang "giữ chỗ" - giống điều kiện WHERE của constraint no_overlapping_viewings. */
    private static final String HOLDING_STATUSES = "('" + PropertyViewing.PENDING + "', '"
            + PropertyViewing.CONFIRMED + "', '" + PropertyViewing.COMPLETED + "')";

    /** Các cột lấy cho 1 lịch hẹn + tên căn hộ + thông tin chủ căn hộ để hiển thị. */
    private static final String COLUMNS = "v.viewing_id, v.customer_id, v.property_id, v.owner_id, v.start_time, "
            + "v.end_time, v.status, v.customer_name, v.customer_phone, v.note, v.cancellation_reason, "
            + "v.created_at, v.updated_at, p.title, ou.full_name AS owner_name, ou.phone AS owner_phone, "
            + "cu.full_name AS customer_full_name, cu.phone AS customer_user_phone ";

    private static final String FROM = "FROM property_viewings v "
            + "JOIN properties p ON p.property_id = v.property_id "
            + "JOIN users ou ON ou.user_id = v.owner_id "
            + "JOIN users cu ON cu.user_id = v.customer_id ";

    @Override
    public List<LocalDateTime> bookedStartTimes(long propertyId, LocalDate date) {
        String sql = "SELECT start_time "
                + "FROM property_viewings "
                + "WHERE property_id = ? "
                + "AND start_time::date = ? "
                + "AND status IN " + HOLDING_STATUSES + " "
                + "ORDER BY start_time";

        List<LocalDateTime> startTimes = new ArrayList<LocalDateTime>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, propertyId);
                statement.setObject(2, date);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        startTimes.add(rs.getObject("start_time", LocalDateTime.class));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return startTimes;
    }

    @Override
    public Map<LocalDate, Integer> bookedCountByDay(long propertyId, LocalDate from, LocalDate to) {
        String sql = "SELECT start_time::date AS day, COUNT(*) AS booked "
                + "FROM property_viewings "
                + "WHERE property_id = ? "
                + "AND start_time::date BETWEEN ? AND ? "
                + "AND status IN " + HOLDING_STATUSES + " "
                + "GROUP BY start_time::date";

        Map<LocalDate, Integer> countByDay = new HashMap<LocalDate, Integer>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, propertyId);
                statement.setObject(2, from);
                statement.setObject(3, to);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        LocalDate day = rs.getObject("day", LocalDate.class);
                        int booked = rs.getInt("booked");
                        countByDay.put(day, booked);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return countByDay;
    }

    @Override
    public long create(PropertyViewing viewing) {
        // owner_id không cần truyền: trigger trg_00_assign_viewing_owner tự lấy từ apartments.owner_id
        String sql = "INSERT INTO property_viewings (customer_id, property_id, start_time, end_time, status, "
                + "customer_name, customer_phone, note) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?) "
                + "RETURNING viewing_id";

        long newId = 0;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, viewing.getCustomerId());
                statement.setLong(2, viewing.getPropertyId());
                statement.setObject(3, viewing.getStartTime());
                statement.setObject(4, viewing.getEndTime());
                statement.setString(5, viewing.getStatus());
                statement.setString(6, viewing.getCustomerName());
                statement.setString(7, viewing.getCustomerPhone());
                statement.setString(8, viewing.getNote());
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        newId = rs.getLong("viewing_id");
                    }
                }
            }
        } catch (SQLException e) {
            // 2 người đặt cùng 1 khung giờ -> DB chặn bằng EXCLUDE constraint
            if (EXCLUSION_VIOLATION.equals(e.getSQLState())) {
                throw new SlotTakenException();
            }
            throw new RuntimeException(e);
        }
        return newId;
    }

    @Override
    public PropertyViewing findById(long viewingId) {
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE v.viewing_id = ?";

        PropertyViewing viewing = null;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, viewingId);
                try (ResultSet rs = statement.executeQuery()) {
                    if (rs.next()) {
                        viewing = mapViewing(rs);
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return viewing;
    }

    @Override
    public List<PropertyViewing> findByCustomer(long customerId) {
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE v.customer_id = ? "
                + "ORDER BY v.start_time DESC";
        return findList(sql, customerId);
    }

    @Override
    public List<PropertyViewing> findByOwner(long ownerId) {
        String sql = "SELECT " + COLUMNS + FROM
                + "WHERE v.owner_id = ? "
                + "ORDER BY v.start_time DESC";
        return findList(sql, ownerId);
    }

    /** Chạy câu SELECT có 1 tham số id, trả về danh sách lịch hẹn. */
    private static List<PropertyViewing> findList(String sql, long id) {
        List<PropertyViewing> viewings = new ArrayList<PropertyViewing>();
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setLong(1, id);
                try (ResultSet rs = statement.executeQuery()) {
                    while (rs.next()) {
                        viewings.add(mapViewing(rs));
                    }
                }
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return viewings;
    }

    @Override
    public boolean changeStatus(long viewingId, long userId, boolean byOwner, String fromStatus,
                                String toStatus, String reason) {
        // Tên cột lấy từ hằng trong code (không phải dữ liệu người dùng) nên ghép chuỗi được
        String userColumn;
        if (byOwner) {
            userColumn = "owner_id";
        } else {
            userColumn = "customer_id";
        }
        String sql = "UPDATE property_viewings "
                + "SET status = ?, cancellation_reason = ?, updated_at = CURRENT_TIMESTAMP "
                + "WHERE viewing_id = ? "
                + "AND " + userColumn + " = ? "
                + "AND status = ?";

        int updatedRows = 0;
        try (Connection connection = Database.getConnection()) {
            try (PreparedStatement statement = connection.prepareStatement(sql)) {
                statement.setString(1, toStatus);
                statement.setString(2, reason);
                statement.setLong(3, viewingId);
                statement.setLong(4, userId);
                statement.setString(5, fromStatus);
                updatedRows = statement.executeUpdate();
            }
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        return updatedRows == 1;
    }

    /** Đọc 1 dòng ResultSet (theo COLUMNS ở trên) thành 1 object PropertyViewing. */
    private static PropertyViewing mapViewing(ResultSet rs) throws SQLException {
        PropertyViewing viewing = new PropertyViewing();
        viewing.setViewingId(rs.getLong("viewing_id"));
        viewing.setCustomerId(rs.getLong("customer_id"));
        viewing.setPropertyId(rs.getLong("property_id"));
        viewing.setOwnerId(rs.getLong("owner_id"));
        viewing.setStartTime(rs.getObject("start_time", LocalDateTime.class));
        viewing.setEndTime(rs.getObject("end_time", LocalDateTime.class));
        viewing.setStatus(rs.getString("status"));
        viewing.setNote(rs.getString("note"));
        viewing.setCancellationReason(rs.getString("cancellation_reason"));
        viewing.setCreatedAt(rs.getObject("created_at", LocalDateTime.class));
        viewing.setUpdatedAt(rs.getObject("updated_at", LocalDateTime.class));
        viewing.setPropertyTitle(rs.getString("title"));
        viewing.setOwnerName(rs.getString("owner_name"));
        viewing.setOwnerPhone(rs.getString("owner_phone"));

        // customer_name / customer_phone có thể NULL (dữ liệu mẫu) -> lấy tên, SĐT trong tài khoản khách
        String customerName = rs.getString("customer_name");
        if (customerName == null || customerName.trim().isEmpty()) {
            customerName = rs.getString("customer_full_name");
        }
        viewing.setCustomerName(customerName);
        String customerPhone = rs.getString("customer_phone");
        if (customerPhone == null || customerPhone.trim().isEmpty()) {
            customerPhone = rs.getString("customer_user_phone");
        }
        viewing.setCustomerPhone(customerPhone);
        return viewing;
    }
}
