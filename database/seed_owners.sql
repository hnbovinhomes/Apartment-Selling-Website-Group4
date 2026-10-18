-- =====================================================================
-- seed_owners.sql  -  chạy SAU KHI restore apartment_db.sql
--  0. Sửa lỗi trigger check_admin_actor (không INSERT được vào listings, admin_activity_logs)
--  1. Đặt mật khẩu (đã băm BCrypt) cho 6 tài khoản mẫu
--  2. Thêm 8 chủ căn hộ mới -> tổng cộng 10 chủ căn hộ
--  3. Chia đều 101 căn hộ cho 10 chủ (mỗi người ~10 căn)
--  4. Cập nhật owner_id của listings và property_viewings cho khớp
-- Mật khẩu của TẤT CẢ tài khoản: Matkhau123  (đăng nhập bằng số điện thoại hoặc email)
-- Cột password_hash KHÔNG lưu chữ "Matkhau123" mà lưu chuỗi băm BCrypt của nó:
--   $2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.
--   ($2a = BCrypt, $10 = 2^10 vòng băm, 22 ký tự kế tiếp là salt, phần còn lại là hash)
-- Chuỗi này tạo bằng PasswordHasher.hashPassword("Matkhau123") trong Java.
-- Chạy lại nhiều lần vẫn được (không tạo trùng tài khoản).
-- =====================================================================
BEGIN;

-- 0. SỬA LỖI TRIGGER check_admin_actor() trong apartment_db.sql
--    Bản cũ dùng CASE đọc cùng lúc NEW.admin_id, NEW.assigned_admin_id, NEW.reviewed_by
--    -> bảng nào cũng thiếu 2 trong 3 cột đó nên báo lỗi: record "new" has no field "admin_id"
--    -> không INSERT được vào listings (đăng tin), admin_activity_logs, property_reports, report_actions.
--    Bản sửa dùng IF / ELSIF: mỗi bảng chỉ đọc đúng cột của bảng đó.
CREATE OR REPLACE FUNCTION public.check_admin_actor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_id BIGINT; v_role TEXT; v_active SMALLINT;
BEGIN
 IF TG_TABLE_NAME = 'report_actions' OR TG_TABLE_NAME = 'admin_activity_logs' THEN
  v_id := NEW.admin_id;
 ELSIF TG_TABLE_NAME = 'property_reports' THEN
  v_id := NEW.assigned_admin_id;
 ELSIF TG_TABLE_NAME = 'listings' THEN
  v_id := NEW.reviewed_by;
 END IF;
 IF v_id IS NOT NULL THEN
  SELECT role, is_active INTO v_role, v_active FROM public.users WHERE user_id = v_id;
  IF v_role IS DISTINCT FROM 'ADMIN' OR v_active IS DISTINCT FROM 1 THEN
   RAISE EXCEPTION 'Tài khoản % không phải Admin đang hoạt động', v_id;
  END IF;
 END IF;
 RETURN NEW;
END $$;

-- 1. Mật khẩu (đã băm) cho 6 tài khoản mẫu (admin, 3 khách, 2 chủ căn hộ)
UPDATE users
SET password_hash = '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.',
    updated_at = CURRENT_TIMESTAMP
WHERE phone IN ('0900000001', '0900000002', '0900000003', '0900000004', '0900000005', '0900000006');

-- 2. Thêm 8 chủ căn hộ mới (username phải bằng phone - CHECK chk_username_equals_phone)
INSERT INTO users (username, email, password_hash, role, full_name, phone)
VALUES
    ('0900000007', 'owner03@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Lê Thị Mai',       '0900000007'),
    ('0900000008', 'owner04@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Phạm Quốc Bảo',    '0900000008'),
    ('0900000009', 'owner05@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Võ Thanh Tâm',     '0900000009'),
    ('0900000010', 'owner06@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Đặng Minh Khoa',   '0900000010'),
    ('0900000011', 'owner07@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Huỳnh Ngọc Hân',   '0900000011'),
    ('0900000012', 'owner08@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Bùi Gia Huy',      '0900000012'),
    ('0900000013', 'owner09@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Ngô Thùy Linh',    '0900000013'),
    ('0900000014', 'owner10@gmail.com', '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.', 'OWNER', 'Trịnh Đức Anh',    '0900000014')
ON CONFLICT DO NOTHING;

-- 8 chủ mới nếu đã tạo từ lần chạy trước (còn lưu mật khẩu chưa băm) thì cập nhật luôn
UPDATE users
SET password_hash = '$2a$10$BAGLuloAP/v2fxLcwyN/y.Q0mZ9Z0EuvYTDEj8LaAkSxqXGN3J7Q.'
WHERE phone BETWEEN '0900000007' AND '0900000014'
  AND password_hash NOT LIKE '$2%';

-- mỗi tài khoản OWNER phải có 1 dòng trong bảng owners
INSERT INTO owners (owner_id)
SELECT u.user_id
FROM users u
WHERE u.role = 'OWNER'
  AND NOT EXISTS (SELECT 1 FROM owners o WHERE o.owner_id = u.user_id);

-- 3. Chia đều căn hộ: NTILE(10) chia danh sách căn (theo apartment_id) thành 10 nhóm gần bằng nhau,
--    nhóm 1 -> chủ thứ 1, nhóm 2 -> chủ thứ 2 ...
--    Trigger trg_owner_change chặn đổi chủ khi căn đã có tin đăng / lịch hẹn,
--    nên tạm tắt trigger này, đổi xong (và sửa listings, property_viewings cho khớp) thì bật lại.
ALTER TABLE apartments DISABLE TRIGGER trg_owner_change;

WITH owner_list AS (
    SELECT owner_id,
           ROW_NUMBER() OVER (ORDER BY owner_id) AS group_no
    FROM owners
),
apartment_groups AS (
    SELECT apartment_id,
           NTILE(10) OVER (ORDER BY apartment_id) AS group_no
    FROM apartments
)
UPDATE apartments a
SET owner_id = o.owner_id
FROM apartment_groups g
JOIN owner_list o ON o.group_no = g.group_no
WHERE a.apartment_id = g.apartment_id;

ALTER TABLE apartments ENABLE TRIGGER trg_owner_change;

-- 4. Tin đăng và lịch hẹn phải cùng chủ với căn hộ (trigger trg_listing_owner, trg_viewing_owner kiểm tra)
UPDATE listings l
SET owner_id = a.owner_id,
    updated_at = CURRENT_TIMESTAMP
FROM properties p
JOIN apartments a ON a.apartment_id = p.apartment_id
WHERE l.property_id = p.property_id
  AND l.owner_id <> a.owner_id;

UPDATE property_viewings v
SET owner_id = a.owner_id,
    updated_at = CURRENT_TIMESTAMP
FROM properties p
JOIN apartments a ON a.apartment_id = p.apartment_id
WHERE v.property_id = p.property_id
  AND v.owner_id <> a.owner_id;

-- Web đăng tin không cần duyệt: mọi tin đều xem như đã đăng
UPDATE listings
SET moderation_status = 'PUBLISHED'
WHERE moderation_status <> 'PUBLISHED';

COMMIT;

-- Kiểm tra: mỗi chủ căn hộ có bao nhiêu căn
SELECT u.user_id, u.full_name, u.phone, u.email, u.password_hash, COUNT(a.apartment_id) AS so_can_ho
FROM owners o
JOIN users u ON u.user_id = o.owner_id
LEFT JOIN apartments a ON a.owner_id = o.owner_id
GROUP BY u.user_id, u.full_name, u.phone, u.email, u.password_hash
ORDER BY u.user_id;
