package com.apartment.website.appointment.repository;

import com.apartment.website.appointment.entity.PropertyViewing;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public interface PropertyViewingRepository {
    /** Giờ bắt đầu của các lịch đang giữ chỗ (chờ xác nhận / đã xác nhận / đã hoàn thành) của căn trong 1 ngày. */
    List<LocalDateTime> bookedStartTimes(long propertyId, LocalDate date);

    /** Số lịch đang giữ chỗ theo từng ngày trong khoảng [from, to]. */
    Map<LocalDate, Integer> bookedCountByDay(long propertyId, LocalDate from, LocalDate to);

    /** Lưu lịch hẹn (status = Chờ xác nhận), trả về viewing_id. Ném SlotTakenException nếu trùng giờ. */
    long create(PropertyViewing viewing);

    /** Trả về null nếu không có. */
    PropertyViewing findById(long viewingId);

    /** Lịch hẹn của 1 khách, mới nhất trước. */
    List<PropertyViewing> findByCustomer(long customerId);

    /** Lịch hẹn của các căn thuộc 1 chủ căn hộ, mới nhất trước. */
    List<PropertyViewing> findByOwner(long ownerId);

    /**
     * Đổi trạng thái lịch hẹn, chỉ khi lịch đó thuộc đúng người đang thao tác và đang ở trạng thái fromStatus.
     * byOwner = true: kiểm tra owner_id = userId; false: kiểm tra customer_id = userId.
     * Trả về true nếu đổi được (có 1 dòng bị UPDATE).
     */
    boolean changeStatus(long viewingId, long userId, boolean byOwner, String fromStatus, String toStatus, String reason);
}
