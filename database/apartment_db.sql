--
-- PostgreSQL database dump
--

\restrict 4FtjGtIDuzKzhiBxuGcCYgzco7Ef1WVgEeHX0JCrZXaYpWcoByQa2XTbjukuopJ

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-10-14 15:29:58

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 26576)
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- TOC entry 5600 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- TOC entry 438 (class 1255 OID 27503)
-- Name: assign_viewing_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_viewing_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_owner BIGINT;
BEGIN
 SELECT a.owner_id INTO v_owner FROM public.properties p
 JOIN public.apartments a ON a.apartment_id=p.apartment_id WHERE p.property_id=NEW.property_id;
 IF v_owner IS NULL THEN RAISE EXCEPTION 'Không tìm thấy Owner cho property_id=%',NEW.property_id; END IF;
 NEW.owner_id := v_owner;
 RETURN NEW;
END $$;


--
-- TOC entry 477 (class 1255 OID 27495)
-- Name: check_admin_actor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_admin_actor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_id BIGINT; v_role TEXT; v_active SMALLINT;
BEGIN
 v_id := CASE TG_TABLE_NAME
  WHEN 'report_actions' THEN NEW.admin_id
  WHEN 'admin_activity_logs' THEN NEW.admin_id
  WHEN 'property_reports' THEN NEW.assigned_admin_id
  WHEN 'listings' THEN NEW.reviewed_by
  ELSE NULL END;
 IF v_id IS NOT NULL THEN
  SELECT role,is_active INTO v_role,v_active FROM public.users WHERE user_id=v_id;
  IF v_role IS DISTINCT FROM 'ADMIN' OR v_active IS DISTINCT FROM 1 THEN
   RAISE EXCEPTION 'Tài khoản % không phải Admin đang hoạt động',v_id;
  END IF;
 END IF;
 RETURN NEW;
END $$;


--
-- TOC entry 480 (class 1255 OID 27500)
-- Name: check_customer_action(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_customer_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_role TEXT; v_active SMALLINT;
BEGIN
 SELECT role,is_active INTO v_role,v_active FROM public.users WHERE user_id=NEW.customer_id;
 IF v_role IS DISTINCT FROM 'CUSTOMER' OR v_active IS DISTINCT FROM 1 THEN
  RAISE EXCEPTION 'Khách hàng % không hợp lệ hoặc đã bị khóa',NEW.customer_id;
 END IF;
 RETURN NEW;
END $$;


--
-- TOC entry 327 (class 1255 OID 19830)
-- Name: enforce_listing_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_listing_owner() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE expected_owner BIGINT; expected_type VARCHAR(10);
BEGIN
 SELECT a.owner_id,p.listing_type INTO expected_owner,expected_type FROM properties p JOIN apartments a ON a.apartment_id=p.apartment_id WHERE p.property_id=NEW.property_id;
 IF expected_owner IS NULL OR NEW.owner_id<>expected_owner OR NEW.listing_type<>expected_type THEN
  RAISE EXCEPTION 'Owner hoặc loại tin đăng không khớp căn hộ';
 END IF;
 RETURN NEW;
END $$;


--
-- TOC entry 459 (class 1255 OID 19828)
-- Name: enforce_owner_consistency(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_owner_consistency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE expected_owner BIGINT;
BEGIN
 SELECT a.owner_id INTO expected_owner FROM properties p JOIN apartments a ON a.apartment_id=p.apartment_id WHERE p.property_id=NEW.property_id;
 IF expected_owner IS NULL OR NEW.owner_id<>expected_owner THEN
  RAISE EXCEPTION 'Owner không khớp căn hộ của property_id=%',NEW.property_id;
 END IF;
 RETURN NEW;
END $$;


--
-- TOC entry 348 (class 1255 OID 19832)
-- Name: prevent_owner_change_with_links(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_owner_change_with_links() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.owner_id<>OLD.owner_id AND EXISTS (
  SELECT 1 FROM properties p WHERE p.apartment_id=OLD.apartment_id AND (
    EXISTS(SELECT 1 FROM listings l WHERE l.property_id=p.property_id) OR
    EXISTS(SELECT 1 FROM property_viewings v WHERE v.property_id=p.property_id)
  )
 ) THEN RAISE EXCEPTION 'Cần chuyển giao tin đăng và lịch hẹn trước khi đổi chủ sở hữu'; END IF;
 RETURN NEW;
END $$;


--
-- TOC entry 366 (class 1255 OID 19842)
-- Name: propagate_apartment_area(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.propagate_apartment_area() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 UPDATE properties SET area=NEW.area WHERE apartment_id=NEW.apartment_id;
 RETURN NEW;
END $$;


--
-- TOC entry 475 (class 1255 OID 19840)
-- Name: sync_property_area(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_property_area() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 SELECT a.area INTO NEW.area FROM apartments a WHERE a.apartment_id = NEW.apartment_id;
 RETURN NEW;
END $$;


SET default_table_access_method = heap;

--
-- TOC entry 252 (class 1259 OID 27477)
-- Name: admin_activity_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_activity_logs (
    log_id bigint NOT NULL,
    admin_id bigint NOT NULL,
    action_type character varying(60) NOT NULL,
    target_type character varying(40),
    target_id bigint,
    description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- TOC entry 251 (class 1259 OID 27476)
-- Name: admin_activity_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.admin_activity_logs ALTER COLUMN log_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.admin_activity_logs_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 19654)
-- Name: apartments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apartments (
    apartment_id bigint NOT NULL,
    building_id bigint NOT NULL,
    owner_id bigint NOT NULL,
    apartment_code character varying(50) NOT NULL,
    floor_number bigint NOT NULL,
    room_number character varying(50),
    area numeric(10,2) NOT NULL,
    bedrooms bigint DEFAULT 0 NOT NULL,
    bathrooms bigint DEFAULT 0 NOT NULL,
    balcony_area numeric(10,2),
    direction character varying(50),
    view_type character varying(100),
    legal_status character varying(100) DEFAULT 'Chưa cập nhật'::character varying NOT NULL,
    status character varying(30) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT apartments_area_check CHECK ((area > (0)::numeric)),
    CONSTRAINT apartments_balcony_area_check CHECK ((balcony_area >= (0)::numeric)),
    CONSTRAINT apartments_bathrooms_check CHECK ((bathrooms >= 0)),
    CONSTRAINT apartments_bedrooms_check CHECK ((bedrooms >= 0)),
    CONSTRAINT apartments_floor_number_check CHECK ((floor_number >= 0)),
    CONSTRAINT ck_legal_vn CHECK (((legal_status)::text = ANY ((ARRAY['Sổ hồng/Sổ đỏ'::character varying, 'Hợp đồng cho thuê'::character varying, 'Chưa cập nhật'::character varying, 'Đang thế chấp'::character varying, 'Đang tranh chấp'::character varying])::text[])))
);


--
-- TOC entry 230 (class 1259 OID 19653)
-- Name: apartments_apartment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.apartments ALTER COLUMN apartment_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.apartments_apartment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 19631)
-- Name: buildings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.buildings (
    building_id bigint NOT NULL,
    building_code character varying(30) NOT NULL,
    building_name character varying(200) NOT NULL,
    address character varying(500) NOT NULL,
    ward character varying(100),
    district character varying(100),
    city character varying(100),
    total_floors bigint,
    total_apartments bigint DEFAULT 0 NOT NULL,
    year_built numeric(4,0),
    description text,
    status character varying(30) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    apartments_in_database bigint DEFAULT 0 NOT NULL,
    CONSTRAINT buildings_total_apartments_check CHECK ((total_apartments >= 0)),
    CONSTRAINT buildings_total_floors_check CHECK ((total_floors > 0))
);


--
-- TOC entry 228 (class 1259 OID 19630)
-- Name: buildings_building_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.buildings ALTER COLUMN building_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.buildings_building_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 19619)
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    customer_id bigint NOT NULL
);


--
-- TOC entry 242 (class 1259 OID 27328)
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    favorite_id bigint NOT NULL,
    user_id bigint NOT NULL,
    property_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- TOC entry 241 (class 1259 OID 27327)
-- Name: favorites_favorite_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.favorites ALTER COLUMN favorite_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.favorites_favorite_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 235 (class 1259 OID 19727)
-- Name: listings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listings (
    listing_id bigint NOT NULL,
    listing_code character varying(50) NOT NULL,
    owner_id bigint NOT NULL,
    property_id bigint NOT NULL,
    listing_title character varying(200),
    asking_price numeric(18,2) NOT NULL,
    description text,
    post_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    expiry_date timestamp without time zone,
    status character varying(30) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    listing_type character varying(10) NOT NULL,
    moderation_status character varying(24) DEFAULT 'PENDING_REVIEW'::character varying NOT NULL,
    reviewed_by bigint,
    reviewed_at timestamp without time zone,
    moderation_reason text,
    CONSTRAINT ck_listings_moderation_status CHECK (((moderation_status)::text = ANY ((ARRAY['PENDING_REVIEW'::character varying, 'PUBLISHED'::character varying, 'REJECTED'::character varying, 'HIDDEN'::character varying])::text[]))),
    CONSTRAINT listings_asking_price_check CHECK ((asking_price >= (0)::numeric)),
    CONSTRAINT listings_check CHECK (((expiry_date IS NULL) OR (expiry_date >= post_date))),
    CONSTRAINT listings_listing_type_check CHECK (((listing_type)::text = ANY ((ARRAY['SALE'::character varying, 'RENT'::character varying])::text[])))
);


--
-- TOC entry 234 (class 1259 OID 19726)
-- Name: listings_listing_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.listings ALTER COLUMN listing_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.listings_listing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 27385)
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    notification_id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying(200) NOT NULL,
    message text NOT NULL,
    notification_type character varying(40) DEFAULT 'SYSTEM'::character varying NOT NULL,
    related_type character varying(40),
    related_id bigint,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    read_at timestamp without time zone,
    CONSTRAINT ck_notification_read_at CHECK (((read_at IS NULL) OR (is_read = true)))
);


--
-- TOC entry 245 (class 1259 OID 27384)
-- Name: notifications_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.notifications ALTER COLUMN notification_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.notifications_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 19608)
-- Name: owners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.owners (
    owner_id bigint NOT NULL,
    tax_code character varying(50),
    identity_verified boolean DEFAULT false NOT NULL
);


--
-- TOC entry 233 (class 1259 OID 19694)
-- Name: properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.properties (
    property_id bigint NOT NULL,
    apartment_id bigint NOT NULL,
    title character varying(200) NOT NULL,
    price numeric(18,2) NOT NULL,
    price_per_m2 numeric(18,2),
    description text,
    address character varying(500),
    status character varying(30) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    listing_type character varying(10) NOT NULL,
    is_illustrative boolean DEFAULT false NOT NULL,
    area numeric(10,2) NOT NULL,
    district character varying(100),
    CONSTRAINT ck_properties_area_positive CHECK ((area > (0)::numeric)),
    CONSTRAINT ck_rent_not_sold CHECK ((((listing_type)::text <> 'RENT'::text) OR ((status)::text <> 'SOLD'::text))),
    CONSTRAINT properties_listing_type_check CHECK (((listing_type)::text = ANY ((ARRAY['SALE'::character varying, 'RENT'::character varying])::text[]))),
    CONSTRAINT properties_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT properties_price_per_m2_check CHECK ((price_per_m2 >= (0)::numeric)),
    CONSTRAINT properties_status_check CHECK (((status)::text = ANY ((ARRAY['AVAILABLE'::character varying, 'RESERVED'::character varying, 'SOLD'::character varying, 'HIDDEN'::character varying])::text[])))
);


--
-- TOC entry 232 (class 1259 OID 19693)
-- Name: properties_property_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.properties ALTER COLUMN property_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.properties_property_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 19766)
-- Name: property_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property_images (
    image_id bigint NOT NULL,
    property_id bigint NOT NULL,
    image_url character varying(500) NOT NULL,
    is_thumbnail smallint DEFAULT 0 NOT NULL,
    uploaded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT property_images_is_thumbnail_check CHECK ((is_thumbnail = ANY (ARRAY[0, 1])))
);


--
-- TOC entry 236 (class 1259 OID 19765)
-- Name: property_images_image_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.property_images ALTER COLUMN image_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.property_images_image_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 248 (class 1259 OID 27410)
-- Name: property_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property_reports (
    report_id bigint NOT NULL,
    property_id bigint NOT NULL,
    reporter_id bigint NOT NULL,
    review_id bigint,
    reason character varying(60) NOT NULL,
    description text NOT NULL,
    status character varying(24) DEFAULT 'PENDING'::character varying NOT NULL,
    assigned_admin_id bigint,
    resolution_note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resolved_at timestamp without time zone,
    CONSTRAINT property_reports_reason_check CHECK (((reason)::text = ANY ((ARRAY['SUSPECTED_FAKE'::character varying, 'WRONG_INFORMATION'::character varying, 'MISLEADING_IMAGES'::character varying, 'DUPLICATE'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT property_reports_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'INVESTIGATING'::character varying, 'RESOLVED'::character varying, 'DISMISSED'::character varying])::text[])))
);


--
-- TOC entry 247 (class 1259 OID 27409)
-- Name: property_reports_report_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.property_reports ALTER COLUMN report_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.property_reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 19788)
-- Name: property_viewings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.property_viewings (
    viewing_id bigint NOT NULL,
    customer_id bigint NOT NULL,
    property_id bigint NOT NULL,
    owner_id bigint NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    customer_name character varying(150),
    customer_phone character varying(20),
    note character varying(1000),
    cancellation_reason character varying(500),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_viewing_duration CHECK ((end_time = (start_time + '00:30:00'::interval))),
    CONSTRAINT property_viewings_check CHECK ((end_time > start_time)),
    CONSTRAINT property_viewings_status_check CHECK (((status)::text = ANY ((ARRAY['Chờ xác nhận'::character varying, 'Đã xác nhận'::character varying, 'Đã hoàn thành'::character varying, 'Đã hủy'::character varying, 'Đã từ chối'::character varying])::text[])))
);


--
-- TOC entry 238 (class 1259 OID 19787)
-- Name: property_viewings_viewing_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.property_viewings ALTER COLUMN viewing_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.property_viewings_viewing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 250 (class 1259 OID 27451)
-- Name: report_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_actions (
    action_id bigint NOT NULL,
    report_id bigint NOT NULL,
    admin_id bigint NOT NULL,
    action_type character varying(40) NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT report_actions_action_type_check CHECK (((action_type)::text = ANY ((ARRAY['CONTACT_OWNER'::character varying, 'REQUEST_EVIDENCE'::character varying, 'OWNER_RESPONDED'::character varying, 'HIDE_LISTING'::character varying, 'RESTORE_LISTING'::character varying, 'WARN_OWNER'::character varying, 'BLOCK_OWNER'::character varying, 'RESOLVE_REPORT'::character varying, 'DISMISS_REPORT'::character varying, 'OTHER'::character varying])::text[])))
);


--
-- TOC entry 249 (class 1259 OID 27450)
-- Name: report_actions_action_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.report_actions ALTER COLUMN action_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.report_actions_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 27352)
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    review_id bigint NOT NULL,
    customer_id bigint NOT NULL,
    property_id bigint NOT NULL,
    rating smallint NOT NULL,
    comment text,
    status character varying(20) DEFAULT 'VISIBLE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT reviews_status_check CHECK (((status)::text = ANY ((ARRAY['VISIBLE'::character varying, 'HIDDEN'::character varying])::text[])))
);


--
-- TOC entry 243 (class 1259 OID 27351)
-- Name: reviews_review_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.reviews ALTER COLUMN review_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.reviews_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 225 (class 1259 OID 19588)
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    user_id bigint NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(150) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active smallint DEFAULT 1 NOT NULL,
    full_name character varying(150) NOT NULL,
    phone character varying(20) NOT NULL,
    cccd character varying(12),
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    last_login_at timestamp without time zone,
    blocked_reason text,
    blocked_at timestamp without time zone,
    blocked_by bigint,
    CONSTRAINT chk_username_equals_phone CHECK (((username)::text = (phone)::text)),
    CONSTRAINT chk_users_cccd_format CHECK (((cccd IS NULL) OR ((cccd)::text ~ '^([0-9]{9}|[0-9]{12})$'::text))),
    CONSTRAINT users_is_active_check CHECK ((is_active = ANY (ARRAY[0, 1]))),
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['ADMIN'::character varying, 'CUSTOMER'::character varying, 'OWNER'::character varying])::text[])))
);


--
-- TOC entry 224 (class 1259 OID 19587)
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.users ALTER COLUMN user_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 255 (class 1259 OID 27515)
-- Name: vw_danh_gia_can_ho; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_danh_gia_can_ho AS
 SELECT p.property_id,
    p.title,
    count(r.review_id) AS so_danh_gia,
    round(avg(r.rating), 2) AS diem_trung_binh
   FROM (public.properties p
     LEFT JOIN public.reviews r ON (((r.property_id = p.property_id) AND ((r.status)::text = 'VISIBLE'::text))))
  GROUP BY p.property_id, p.title;


--
-- TOC entry 240 (class 1259 OID 27305)
-- Name: vw_lich_hen_chi_tiet; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_lich_hen_chi_tiet AS
 SELECT viewing_id AS ma_lich_hen,
    customer_id AS ma_khach_hang,
    property_id AS ma_bat_dong_san,
    owner_id AS ma_chu_so_huu,
    to_char(start_time, 'DD/MM/YYYY HH24:MI'::text) AS thoi_gian_bat_dau,
    to_char(end_time, 'DD/MM/YYYY HH24:MI'::text) AS thoi_gian_ket_thuc,
    status AS trang_thai,
    customer_name AS ten_khach_hang,
    customer_phone AS so_dien_thoai,
    note AS ghi_chu,
    cancellation_reason AS ly_do_huy
   FROM public.property_viewings pv;


--
-- TOC entry 253 (class 1259 OID 27505)
-- Name: vw_lich_hen_tieng_viet; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_lich_hen_tieng_viet AS
 SELECT viewing_id AS ma_lich_hen,
    customer_id AS ma_khach_hang,
    property_id AS ma_bat_dong_san,
    owner_id AS ma_chu_so_huu,
    to_char(start_time, 'DD/MM/YYYY HH24:MI'::text) AS bat_dau,
    to_char(end_time, 'DD/MM/YYYY HH24:MI'::text) AS ket_thuc,
        CASE status
            WHEN 'PENDING'::text THEN 'Chờ xác nhận'::character varying
            WHEN 'CONFIRMED'::text THEN 'Đã xác nhận'::character varying
            WHEN 'COMPLETED'::text THEN 'Đã hoàn thành'::character varying
            WHEN 'CANCELLED'::text THEN 'Đã hủy'::character varying
            WHEN 'REJECTED'::text THEN 'Đã từ chối'::character varying
            ELSE status
        END AS trang_thai,
    note AS ghi_chu
   FROM public.property_viewings v;


--
-- TOC entry 254 (class 1259 OID 27510)
-- Name: vw_thong_ke_owner; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_thong_ke_owner AS
 SELECT o.owner_id AS ma_chu_so_huu,
    u.full_name AS ten_chu_so_huu,
    count(DISTINCT a.apartment_id) AS so_can_ho,
    count(DISTINCT v.viewing_id) AS tong_lich_hen,
    count(DISTINCT v.viewing_id) FILTER (WHERE ((v.status)::text = ANY ((ARRAY['COMPLETED'::character varying, 'Đã hoàn thành'::character varying])::text[]))) AS lich_hoan_thanh,
    count(DISTINCT v.viewing_id) FILTER (WHERE ((v.status)::text = ANY ((ARRAY['CANCELLED'::character varying, 'Đã hủy'::character varying])::text[]))) AS lich_da_huy
   FROM (((public.owners o
     JOIN public.users u ON ((u.user_id = o.owner_id)))
     LEFT JOIN public.apartments a ON ((a.owner_id = o.owner_id)))
     LEFT JOIN public.property_viewings v ON ((v.owner_id = o.owner_id)))
  GROUP BY o.owner_id, u.full_name;


--
-- TOC entry 5594 (class 0 OID 27477)
-- Dependencies: 252
-- Data for Name: admin_activity_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_activity_logs (log_id, admin_id, action_type, target_type, target_id, description, created_at) FROM stdin;
\.


--
-- TOC entry 5574 (class 0 OID 19654)
-- Dependencies: 231
-- Data for Name: apartments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.apartments (apartment_id, building_id, owner_id, apartment_code, floor_number, room_number, area, bedrooms, bathrooms, balcony_area, direction, view_type, legal_status, status, created_at) FROM stdin;
36	3	5	SRC-102	23	03	76.00	2	2	3.80	Đông Nam	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
37	3	5	SRC-104	30	04	210.00	4	4	12.60	Đông Bắc	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
49	3	5	SRC-101	15	05	56.00	1	1	4.48	Tây	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
63	4	5	GTW-101	11	03	52.00	1	1	3.64	Tây Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
39	5	5	SSV-102	22	03	210.00	3	3	16.80	Tây Bắc	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
62	5	5	SSV-101	22	04	136.00	2	2	8.16	Tây Nam	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
56	6	5	TMQ-104	2	02	146.00	4	3	7.30	Đông	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
68	7	5	VCP-101	16	01	54.00	1	1	3.78	Đông Nam	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
35	9	5	VGR-103	17	02	110.00	3	2	4.40	Bắc	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
41	9	5	VGR-102	13	03	78.00	2	2	3.90	Tây	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
58	9	5	VGR-104	17	04	160.00	4	3	11.20	Nam	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
61	10	5	PMC-102	9	03	78.00	2	2	3.90	Đông Bắc	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
50	11	5	TGC-102	22	01	75.00	2	2	3.00	Nam	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
54	11	5	TGC-101	17	02	50.00	1	1	4.00	Tây Nam	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
75	11	5	TGC-104	32	03	190.00	4	4	7.60	Bắc	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
45	12	5	EMP-102	11	01	93.00	2	2	3.72	Đông Bắc	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
55	12	5	EMP-101	9	02	64.00	1	1	2.56	Tây Bắc	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
67	12	5	EMP-103	3	03	155.00	3	3	9.30	Bắc	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
32	13	5	SCV-101	19	03	70.00	2	2	4.20	Đông	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
57	14	5	ESH-102	9	02	90.00	2	2	5.40	Tây	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
70	14	5	ESH-101	16	03	60.00	1	1	2.40	Tây Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
38	15	5	SWP-101	4	01	56.00	1	1	3.92	Tây Nam	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
40	15	5	SWP-104	18	02	230.00	4	4	9.20	Đông	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
65	15	5	SWP-102	28	03	102.00	2	2	4.08	Tây	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
71	15	5	SWP-103	4	04	128.00	3	2	6.40	Tây Bắc	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
43	16	5	CTG-104	15	04	220.00	4	4	15.40	Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
42	17	5	VGP-102	20	01	59.00	2	1	3.54	Nam	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
46	17	5	VGP-103	2	02	72.00	2	2	3.60	Tây Nam	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
72	17	5	VGP-104	23	03	100.00	3	2	6.00	Đông	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
51	18	5	MTP-103	23	01	120.00	3	2	6.00	Bắc	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
73	18	5	MTP-102	9	02	82.00	2	2	5.74	Tây	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
60	20	5	GMS-102	8	01	88.00	2	2	3.52	Đông Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
74	20	5	GMS-101	16	02	59.00	1	1	4.72	Nam	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
52	21	5	INF-102	21	01	82.00	2	2	4.92	Đông Nam	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
53	21	5	INF-103	5	02	120.00	3	2	8.40	Đông Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
64	21	5	INF-101	13	03	58.00	1	1	4.64	Đông	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
66	21	5	INF-104	4	04	150.00	3	3	7.50	Nam	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
33	22	5	MDT-104	9	02	160.00	4	3	11.20	Tây	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
47	22	5	MDT-101	23	03	62.00	1	1	3.72	Tây Bắc	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
48	22	5	MDT-103	2	04	121.00	3	2	8.47	Đông	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
30	23	5	TRV-103	14	01	125.00	3	3	5.00	Tây Nam	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
44	23	5	TRV-104	13	02	240.00	4	4	19.20	Đông Nam	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
59	23	5	TRV-102	19	03	84.00	2	2	6.72	Bắc	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
87	23	5	TRV-101	17	04	57.00	1	1	3.42	Tây Bắc	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
9	24	5	MST-102	11	02	68.00	2	2	5.44	Tây	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
80	24	5	MST-103	4	03	90.00	3	2	3.60	Đông	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
86	24	5	MST-104	10	04	130.00	3	3	6.50	Tây Nam	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
10	25	5	LMN-102	3	01	96.00	3	2	3.84	Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
34	25	5	LMN-104	10	02	200.00	4	4	16.00	Nam	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
98	25	5	LMN-103	21	03	113.00	3	2	7.91	Nam	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
99	25	5	LMN-101	5	04	75.00	2	2	6.00	Bắc	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
69	26	5	DMI-101	9	01	55.00	1	1	4.40	Đông Bắc	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
84	26	5	DMI-102	2	02	88.00	2	2	7.04	Đông Nam	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
91	26	5	DMI-103	23	03	125.00	3	2	6.25	Bắc	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
92	26	5	DMI-104	2	04	210.00	4	4	12.60	Đông Nam	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
6	19	5	EGR-102	11	01	65.00	2	2	3.25	Tây Nam	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
7	24	5	MST-101	15	01	48.00	1	1	2.88	Tây Bắc	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
2	1	5	S9.01-1808	18	08	75.20	3	2	6.00	Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 12:56:50.41717
4	2	6	MT-1503	15	03	65.70	2	2	5.00	Tây Nam	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 12:56:50.41717
5	3	5	SC-2001	20	01	90.50	3	2	8.00	Đông Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 12:56:50.41717
1	1	5	S9.01-1205	12	05	68.50	2	2	5.20	Đông Nam	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	SOLD	2026-10-11 12:56:50.41717
3	2	6	MT-2506	25	06	82.30	3	2	7.00	Đông	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	RESERVED	2026-10-11 12:56:50.41717
21	3	5	SRC-103	17	02	120.00	3	2	6.00	Đông Bắc	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
19	4	5	GTW-103	9	01	122.00	3	2	9.76	Bắc	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
22	4	5	GTW-104	12	02	180.00	4	3	10.80	Tây Nam	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
17	5	5	SSV-103	6	01	330.00	4	4	19.80	Tây	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
29	5	5	SSV-104	21	02	500.00	5	5	40.00	Đông Bắc	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
8	6	5	TMQ-101	2	01	52.00	1	1	3.64	Đông	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
20	8	5	HDC-104	16	01	123.00	3	2	4.92	Đông Nam	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
28	8	5	HDC-102	18	02	86.00	2	2	6.02	Đông Nam	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
31	8	5	HDC-101	3	03	53.00	1	1	2.65	Tây Bắc	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
14	9	5	VGR-101	8	01	50.00	1	1	4.00	Tây Nam	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
12	10	5	PMC-101	2	01	55.00	1	1	3.30	Đông Nam	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
25	10	5	PMC-104	9	02	140.00	3	3	5.60	Tây	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
18	13	5	SCV-102	13	01	80.00	2	2	5.60	Nam	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
26	13	5	SCV-104	23	02	130.00	3	3	6.50	Nam	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
27	14	5	ESH-104	23	01	250.00	4	4	15.00	Bắc	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
11	16	5	CTG-102	7	01	105.00	2	2	5.25	Bắc	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
15	16	5	CTG-101	17	02	70.00	1	1	2.80	Tây Bắc	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
16	16	5	CTG-103	6	03	140.00	3	2	7.00	Đông	Hướng nhìn công viên	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
13	19	5	EGR-103	27	02	85.00	3	2	5.95	Đông Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
24	19	5	EGR-101	5	03	45.00	1	1	3.60	Đông	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
23	22	5	MDT-102	23	01	89.00	2	2	6.23	Tây Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
97	4	5	GTW-102	15	04	85.00	2	2	5.10	Tây	Hướng nhìn nội khu	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
79	6	5	TMQ-102	23	03	78.00	2	2	6.24	Tây Bắc	Hướng nhìn ra sông	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
101	6	5	TMQ-103	9	04	120.00	3	2	6.00	Đông Bắc	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
76	7	5	VCP-102	6	02	78.00	2	2	3.90	Đông Nam	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
77	7	5	VCP-104	13	03	144.00	4	3	8.64	Đông Bắc	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
100	7	5	VCP-103	9	04	115.00	3	2	4.60	Đông Nam	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
85	8	5	HDC-103	3	04	107.00	3	2	4.28	Đông Bắc	Hướng nhìn thành phố	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
82	10	5	PMC-103	16	04	105.00	3	2	6.30	Nam	Hướng nhìn nội khu	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
96	11	5	TGC-103	14	04	105.00	3	2	5.25	Đông	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
88	12	5	EMP-104	6	04	220.00	4	4	15.40	Đông	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
83	13	5	SCV-103	8	04	110.00	3	2	7.70	Bắc	Hướng nhìn hồ bơi	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
78	14	5	ESH-103	16	04	130.00	3	2	9.10	Tây Nam	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
95	17	5	VGP-101	23	04	33.00	1	1	1.32	Tây Bắc	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
81	18	5	MTP-101	9	03	55.00	1	1	2.75	Tây	Hướng nhìn công viên	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
90	18	5	MTP-104	16	04	170.00	4	4	6.80	Nam	Hướng nhìn thành phố	Hợp đồng cho thuê	AVAILABLE	2026-10-11 15:43:02.119508
89	19	5	EGR-104	31	04	95.00	3	2	7.60	Tây	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
93	20	5	GMS-104	5	03	220.00	4	4	15.40	Đông Bắc	Hướng nhìn hồ bơi	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
94	20	5	GMS-103	12	04	133.00	3	3	10.64	Tây Nam	Hướng nhìn ra sông	Sổ hồng/Sổ đỏ	AVAILABLE	2026-10-11 15:43:02.119508
\.


--
-- TOC entry 5572 (class 0 OID 19631)
-- Dependencies: 229
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.buildings (building_id, building_code, building_name, address, ward, district, city, total_floors, total_apartments, year_built, description, status, created_at, apartments_in_database) FROM stdin;
18	B018	The Metropole Thủ Thiêm	Khu đô thị mới Thủ Thiêm	Phường Thủ Thiêm	Quận 2	TP. Hồ Chí Minh	30	4	2018	Tòa nhà The Metropole Thủ Thiêm tại Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
4	B004	The Gateway Thảo Điền	2 Trần Ngọc Diện	Phường Thảo Điền	Quận 2	TP. Hồ Chí Minh	20	4	2020	Tòa nhà The Gateway Thảo Điền tại 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 15. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
5	B005	Serenity Sky Villas	259 Điện Biên Phủ	Phường Xuân Khánh	Quận 3	TP. Hồ Chí Minh	25	4	2021	Tòa nhà Serenity Sky Villas tại 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 22. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
2	B002	Masteri Thảo Điền	159 Xa Lộ Hà Nội	Thảo Điền	Thủ Đức	TP. Hồ Chí Minh	41	2	2016	Tòa nhà Masteri Thảo Điền tại 159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 2 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 25. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 12:56:50.41717	2
3	B003	Sunrise City	23 Nguyễn Hữu Thọ	Tân Hưng	Quận 7	TP. Hồ Chí Minh	35	5	2015	Tòa nhà Sunrise City tại 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 5 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 30. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 12:56:50.41717	5
6	B006	The Marq	29B Nguyễn Đình Chiểu	Phường Đa Kao	Quận 1	TP. Hồ Chí Minh	30	4	2022	Tòa nhà The Marq tại 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
23	B023	The River Thủ Thiêm	Đại lộ Trống Đồng	Phường Thủ Thiêm	Quận 2	TP. Hồ Chí Minh	35	4	2023	Tòa nhà The River Thủ Thiêm tại Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 19. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
24	B024	Masteri Thảo Điền	159 Xa Lộ Hà Nội	Phường Thảo Điền	Quận 2	TP. Hồ Chí Minh	20	4	2016	Tòa nhà Masteri Thảo Điền tại 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 15. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
25	B025	Leman Luxury Apartments	117 Nguyễn Đình Chiểu	Phường Xuân Khánh	Quận 3	TP. Hồ Chí Minh	25	4	2017	Tòa nhà Leman Luxury Apartments tại 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 21. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
26	B026	Đảo Kim Cương (Diamond Island)	Số 1 Đường số 104	Phường Bình Trưng	Thủ Đức	TP. Hồ Chí Minh	30	4	2018	Tòa nhà Đảo Kim Cương (Diamond Island) tại Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
7	B007	Vinhomes Central Park	208 Nguyễn Hữu Cảnh	Phường Thạnh Mỹ Tây	Bình Thạnh	TP. Hồ Chí Minh	35	4	2023	Tòa nhà Vinhomes Central Park tại 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 16. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
15	B015	Sunwah Pearl	90 Nguyễn Hữu Cảnh	Phường Thạnh Mỹ Tây	Bình Thạnh	TP. Hồ Chí Minh	35	4	2023	Tòa nhà Sunwah Pearl tại 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 28. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
16	B016	City Garden	59 Ngô Tất Tố	Phường Thạnh Mỹ Tây	Bình Thạnh	TP. Hồ Chí Minh	20	4	2016	Tòa nhà City Garden tại 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 17. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
9	B009	Vinhomes Golden River (Ba Son)	2 Tôn Đức Thắng	Phường Bến Nghé	Quận 1	TP. Hồ Chí Minh	25	4	2017	Tòa nhà Vinhomes Golden River (Ba Son) tại 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 17. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
10	B010	Palm Heights / Palm City	Đường Song Hành	Phường An Phú	Quận 2	TP. Hồ Chí Minh	30	4	2018	Tòa nhà Palm Heights / Palm City tại Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 16. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
11	B011	The Global City	Đường Đỗ Xuân Hợp	Phường An Phú	Quận 2	TP. Hồ Chí Minh	35	4	2019	Tòa nhà The Global City tại Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 32. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
12	B012	Empire City	Khu đô thị mới Thủ Thiêm	Phường Thủ Thiêm	Quận 2	TP. Hồ Chí Minh	20	4	2020	Tòa nhà Empire City tại Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 11. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
14	B014	Estella Heights	88 Xa Lộ Hà Nội	Phường Thảo Điền	Quận 2	TP. Hồ Chí Minh	30	4	2022	Tòa nhà Estella Heights tại 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
17	B017	Vinhomes Grand Park	Đường Nguyễn Xiển	Phường Long Bình	Quận 9	TP. Hồ Chí Minh	25	4	2017	Tòa nhà Vinhomes Grand Park tại Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
1	B001	Vinhomes Grand Park - S9.01	Nguyễn Xiển	Long Bình	Thủ Đức	TP. Hồ Chí Minh	36	2	2022	Tòa nhà Vinhomes Grand Park - S9.01 tại Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 2 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 18. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 12:56:50.41717	2
8	B008	Hà Đô Centrosa Garden	200 3 Tháng 2	Phường Hòa Hưng	Quận 10	TP. Hồ Chí Minh	20	4	2016	Tòa nhà Hà Đô Centrosa Garden tại 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 18. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
20	B020	Grand Marina Sài Gòn	2 Tôn Đức Thắng	Phường Bến Nghé	Quận 1	TP. Hồ Chí Minh	20	4	2020	Tòa nhà Grand Marina Sài Gòn tại 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 16. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
13	B013	Scenic Valley	Đường Tôn Dật Tiên	Phường Tân Phú	Quận 7	TP. Hồ Chí Minh	25	4	2021	Tòa nhà Scenic Valley tại Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
19	B019	Eco Green Sài Gòn	39/1B Nguyễn Văn Linh	Phường Tân Thuận	Quận 7	TP. Hồ Chí Minh	35	4	2019	Tòa nhà Eco Green Sài Gòn tại 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 31. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
21	B021	The Infiniti at Riviera Point	584 Huỳnh Tấn Phát	Phường Tân Phú	Quận 7	TP. Hồ Chí Minh	25	4	2021	Tòa nhà The Infiniti at Riviera Point tại 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 21. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
22	B022	Midtown Phú Mỹ Hưng	Đường Nguyễn Lương Bằng	Phường Tân Phú	Quận 7	TP. Hồ Chí Minh	30	4	2022	Tòa nhà Midtown Phú Mỹ Hưng tại Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh. Cơ sở dữ liệu hiện có 4 căn hộ thuộc tòa nhà này; tầng cao nhất ghi nhận là tầng 23. Các căn hộ có thông tin diện tích, bố trí phòng, hướng nhìn và hình thức bán hoặc cho thuê riêng trong từng tin đăng.	ACTIVE	2026-10-11 15:43:02.119508	4
\.


--
-- TOC entry 5570 (class 0 OID 19619)
-- Dependencies: 227
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.customers (customer_id) FROM stdin;
2
3
4
\.


--
-- TOC entry 5584 (class 0 OID 27328)
-- Dependencies: 242
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.favorites (favorite_id, user_id, property_id, created_at) FROM stdin;
\.


--
-- TOC entry 5578 (class 0 OID 19727)
-- Dependencies: 235
-- Data for Name: listings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.listings (listing_id, listing_code, owner_id, property_id, listing_title, asking_price, description, post_date, expiry_date, status, created_at, updated_at, listing_type, moderation_status, reviewed_by, reviewed_at, moderation_reason) FROM stdin;
1	LIST-0001	5	1	Căn hộ 2 phòng ngủ Vinhomes Grand Park	3500000000.00	Căn hộ cần bán tại Vinhomes Grand Park - S9.01.\nMã căn: S9.01-1205; tầng 12, phòng 05.\nDiện tích: 68.50 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.20 m².\nĐịa chỉ: Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 12:56:50.41717	2027-01-09 12:56:50.41717	SOLD	2026-10-11 12:56:50.41717	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
3	LIST-0003	6	3	Căn hộ 3 phòng ngủ Masteri Thảo Điền	9000000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MT-2506; tầng 25, phòng 06.\nDiện tích: 82.30 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.00 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 12:56:50.41717	2027-01-09 12:56:50.41717	ACTIVE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	PUBLISHED	\N	\N	\N
4	LIST-0004	6	4	Căn hộ 2 phòng ngủ Masteri Thảo Điền	6500000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MT-1503; tầng 15, phòng 03.\nDiện tích: 65.70 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.00 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 12:56:50.41717	2027-01-09 12:56:50.41717	ACTIVE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	PUBLISHED	\N	\N	\N
5	LIST-0005	5	5	Căn hộ 3 phòng ngủ Sunrise City	7000000000.00	Căn hộ cần bán tại Sunrise City.\nMã căn: SC-2001; tầng 20, phòng 01.\nDiện tích: 90.50 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 8.00 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 12:56:50.41717	2027-01-09 12:56:50.41717	ACTIVE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	PUBLISHED	\N	\N	\N
6	RENT-HDC-103	5	6	Căn 2 phòng ngủ+1 Hà Đô Centrosa Garden góc 2 mặt thoáng cực rộng	9000000000.00	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-103; tầng 3, phòng 04.\nDiện tích: 107.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.28 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
7	RENT-CTG-101	5	7	Căn 1 phòng ngủ City Garden Bình Thạnh thiết kế gợn sóng độc đáo	6500000000.00	Căn hộ cần bán tại City Garden.\nMã căn: CTG-101; tầng 17, phòng 02.\nDiện tích: 70.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.80 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
8	RENT-CTG-102	5	8	Căn 2 phòng ngủ City Garden tháp Crescent tầng cao hướng nhìn Landmark 81	10500000000.00	Căn hộ cần bán tại City Garden.\nMã căn: CTG-102; tầng 7, phòng 01.\nDiện tích: 105.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.25 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
9	RENT-CTG-103	5	9	Căn 3 phòng ngủ City Garden nội thất châu Âu thiết kế cực sang	16000000000.00	Căn hộ cần bán tại City Garden.\nMã căn: CTG-103; tầng 6, phòng 03.\nDiện tích: 140.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.00 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
10	RENT-CTG-104	5	10	Penthouse City Garden thiết kế thông tầng đỉnh cao kiến trúc	37500000000.00	Căn hộ cần bán tại City Garden.\nMã căn: CTG-104; tầng 15, phòng 04.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
11	RENT-DMI-101	5	11	Căn 1 phòng ngủ tháp Hawaii Đảo Kim Cương hướng nhìn sông Sài Gòn êm đềm	6500000000.00	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-101; tầng 9, phòng 01.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.40 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
12	RENT-DMI-102	5	12	Căn 2 phòng ngủ tháp Bora Bora Đảo Kim Cương đầy đủ nội thất hiện đại	10500000000.00	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-102; tầng 2, phòng 02.\nDiện tích: 88.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.04 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
13	RENT-DMI-103	5	13	Căn góc 3 phòng ngủ tháp Maldives Đảo Kim Cương hướng nhìn sông trực diện	16000000000.00	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-103; tầng 23, phòng 03.\nDiện tích: 125.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.25 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
14	RENT-DMI-104	5	14	Căn biệt thự hồ bơi Đảo Kim Cương sân vườn hồ bơi riêng xa xỉ	47500000000.00	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-104; tầng 2, phòng 04.\nDiện tích: 210.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 12.60 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
15	RENT-EGR-101	5	15	Căn 1 phòng ngủ Eco Green Sài Gòn Nguyễn Văn Linh đầy đủ nội thất xinh xắn	3250000000.00	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-101; tầng 5, phòng 03.\nDiện tích: 45.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
16	RENT-EGR-102	5	16	Căn 2 phòng ngủ Eco Green Sài Gòn hướng nhìn công viên Hương Tràm 22 ha	4500000000.00	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-102; tầng 11, phòng 01.\nDiện tích: 65.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.25 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
17	RENT-EGR-103	5	17	Căn góc 3 phòng ngủ Eco Green Sài Gòn tầng cao hướng nhìn sông cầu Phú Mỹ	6500000000.00	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-103; tầng 27, phòng 02.\nDiện tích: 85.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.95 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
18	RENT-EGR-104	5	18	Căn 3 phòng ngủ Eco Green Sài Gòn đầy đủ nội thất gỗ cao cấp	6500000000.00	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-104; tầng 31, phòng 04.\nDiện tích: 95.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.60 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
19	RENT-EMP-101	5	19	Căn 1 phòng ngủ Linden Empire City Thủ Thiêm đầy đủ nội thất xịn	10500000000.00	Căn hộ cần bán tại Empire City.\nMã căn: EMP-101; tầng 9, phòng 02.\nDiện tích: 64.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.56 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
21	RENT-EMP-103	5	21	Căn 3 phòng ngủ Cove Empire City hướng nhìn trực diện sông thang máy riêng	35000000000.00	Căn hộ cần bán tại Empire City.\nMã căn: EMP-103; tầng 3, phòng 03.\nDiện tích: 155.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 9.30 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
22	RENT-EMP-104	5	22	Penthouse Empire City Thủ Thiêm tầng cao hướng nhìn 360 độ cực phẩm	87500000000.00	Căn hộ cần bán tại Empire City.\nMã căn: EMP-104; tầng 6, phòng 04.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
23	RENT-ESH-101	5	23	Căn 1 phòng ngủ Estella Heights thiết kế nghỉ dưỡng đầy đủ nội thất	7000000000.00	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-101; tầng 16, phòng 03.\nDiện tích: 60.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.40 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
24	RENT-ESH-102	5	24	Bán căn 2 phòng ngủ Estella Heights tháp T3 hướng nhìn hồ bơi tràn bờ	10500000000.00	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-102; tầng 9, phòng 02.\nDiện tích: 90.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.40 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
25	RENT-ESH-103	5	25	Căn 3 phòng ngủ Estella Heights tầng cao hướng nhìn trọn thành phố lộng lẫy	15500000000.00	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-103; tầng 16, phòng 04.\nDiện tích: 130.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 9.10 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
26	RENT-ESH-104	5	26	Căn penthouse Estella Heights sân vườn riêng đẳng cấp thượng lưu	37500000000.00	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-104; tầng 23, phòng 01.\nDiện tích: 250.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 15.00 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
27	RENT-GMS-101	5	27	Căn 1 phòng ngủ Tòa Lake Grand Marina Saigon quản lý chuẩn Marriott	22000000000.00	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-101; tầng 16, phòng 02.\nDiện tích: 59.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.72 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
28	RENT-GMS-102	5	28	Bán căn 2 phòng ngủ Grand Marina Saigon hướng nhìn sông cực đẹp	39000000000.00	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-102; tầng 8, phòng 01.\nDiện tích: 88.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.52 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
29	RENT-GMS-103	5	29	Căn 3 phòng ngủ Hàng hiệu Marriott Grand Marina hướng nhìn trung tâm Quận 1	62500000000.00	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-103; tầng 12, phòng 04.\nDiện tích: 133.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 10.64 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
31	RENT-GTW-101	5	31	Bán căn 1 phòng ngủ Gateway Thảo Điền đầy đủ nội thất hiện đại	7000000000.00	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-101; tầng 11, phòng 03.\nDiện tích: 52.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.64 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
32	RENT-GTW-102	5	32	Căn 2 phòng ngủ Gateway Thảo Điền tầng cao hướng nhìn sông Sài Gòn tuyệt đẹp	10500000000.00	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-102; tầng 15, phòng 04.\nDiện tích: 85.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.10 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
33	RENT-GTW-103	5	33	Căn 3 phòng ngủ Gateway Thảo Điền thiết kế sang trọng nội thất cao cấp	16000000000.00	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-103; tầng 9, phòng 01.\nDiện tích: 122.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 9.76 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
34	RENT-GTW-104	5	34	Căn biệt thự sân vườn Gateway Thảo Điền có sân vườn rộng thoáng	40000000000.00	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-104; tầng 12, phòng 02.\nDiện tích: 180.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 10.80 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
35	RENT-HDC-101	5	35	Căn 1 phòng ngủ1WC Hà Đô Centrosa Garden đầy đủ nội thất hiện đại	5750000000.00	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-101; tầng 3, phòng 03.\nDiện tích: 53.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 2.65 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
40	RENT-INF-103	5	40	Căn góc 3 phòng ngủ Riviera Point tầng cao hướng nhìn toàn cảnh Quận 7	10500000000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-103; tầng 5, phòng 02.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 8.40 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
41	RENT-INF-104	5	41	Căn thông tầng The Infiniti Riviera Point thiết kế thông tầng xa hoa	19500000000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-104; tầng 4, phòng 04.\nDiện tích: 150.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.50 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
42	RENT-LMN-101	5	42	Căn 2 phòng ngủ Leman Luxury Nguyễn Đình Chiểu đầy đủ nội thất Thụy Sĩ	10500000000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-101; tầng 5, phòng 04.\nDiện tích: 75.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
43	RENT-LMN-102	5	43	Bán căn 3 phòng ngủ Leman Luxury không gian sống yên tĩnh đẳng cấp	16000000000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-102; tầng 3, phòng 01.\nDiện tích: 96.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.84 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
44	RENT-LMN-103	5	44	Căn góc 3 phòng ngủ Leman Luxury ban công thoáng mát nội thất xịn	17500000000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-103; tầng 21, phòng 03.\nDiện tích: 113.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 7.91 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
45	RENT-LMN-104	5	45	Penthouse Leman Luxury tầng cao sân vườn riêng cực hiếm	47500000000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-104; tầng 10, phòng 02.\nDiện tích: 200.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 16.00 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
46	RENT-MDT-101	5	46	Căn 1 phòng ngủ The Grande Midtown Phú Mỹ Hưng thiết kế Nhật Bản	5750000000.00	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-101; tầng 23, phòng 03.\nDiện tích: 62.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.72 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
37	RENT-HDC-104	5	37	Căn 3 phòng ngủ Hà Đô Centrosa Garden tầng cao hướng nhìn trọn thành phố	12000000000.00	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-104; tầng 16, phòng 01.\nDiện tích: 123.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.92 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
47	RENT-MDT-102	5	47	Bán căn 2 phòng ngủ The Symphony Midtown hướng nhìn Sakura Park	8250000000.00	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-102; tầng 23, phòng 01.\nDiện tích: 89.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 6.23 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
48	RENT-MDT-103	5	48	Căn góc 3 phòng ngủ The Signature Midtown tầng trung hướng nhìn sông biệt thự	12000000000.00	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-103; tầng 2, phòng 04.\nDiện tích: 121.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 8.47 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
49	RENT-MDT-104	5	49	Căn 4 phòng ngủ The Peak Midtown Phú Mỹ Hưng đầy đủ nội thất cao cấp	21500000000.00	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-104; tầng 9, phòng 02.\nDiện tích: 160.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 11.20 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
50	RENT-MST-101	5	50	Bán căn studio Masteri Thảo Điền T4 đầy đủ nội thất xinh xắn	4500000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-101; tầng 15, phòng 01.\nDiện tích: 48.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 2.88 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
51	RENT-MST-102	5	51	Căn hộ 2 phòng ngủ2WC Masteri Thảo Điền T2 hướng nhìn sông Sài Gòn thoáng mát	6500000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-102; tầng 11, phòng 02.\nDiện tích: 68.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 5.44 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
52	RENT-MST-103	5	52	Căn góc 3 phòng ngủ Masteri Thảo Điền T1 tầng cao hướng nhìn Vincom sang trọng	9000000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-103; tầng 4, phòng 03.\nDiện tích: 90.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
53	RENT-MST-104	5	53	Bán thông tầng Masteri Thảo Điền thiết kế hiện đại, đầy đủ tiện nghi	18000000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-104; tầng 10, phòng 04.\nDiện tích: 130.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.50 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
54	RENT-MTP-101	5	54	Căn 1 phòng ngủ Galleria Metropole Thủ Thiêm đầy đủ nội thất cao cấp	25000000.00	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-101; tầng 9, phòng 03.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 2.75 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
55	RENT-MTP-102	5	55	Cho thuê căn 2 phòng ngủ The Crest Metropole hướng nhìn cầu Ba Sơn tuyệt đẹp	38000000.00	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-102; tầng 9, phòng 02.\nDiện tích: 82.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.74 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
56	RENT-MTP-103	5	56	Căn 3 phòng ngủ Opera Metropole Thủ Thiêm ban công rộng hướng nhìn sông	60000000.00	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-103; tầng 23, phòng 01.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
57	RENT-MTP-104	5	57	Căn 4 phòng ngủ cao cấp Metropole Thủ Thiêm thang máy riêng biệt xa hoa	110000000.00	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-104; tầng 16, phòng 04.\nDiện tích: 170.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 6.80 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
58	RENT-PMC-101	5	58	Căn 1 phòng ngủ Palm Heights An Phú đầy đủ nội thất xinh xắn	14000000.00	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-101; tầng 2, phòng 01.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.30 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
59	RENT-PMC-102	5	59	Căn 2 phòng ngủ Palm Heights hướng nhìn sông mát mẻ tầng cao	18500000.00	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-102; tầng 9, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
60	RENT-PMC-103	5	60	Căn góc 3 phòng ngủ Palm Heights diện tích rộng đầy đủ nội thất cao cấp	25000000.00	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-103; tầng 16, phòng 04.\nDiện tích: 105.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 6.30 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
61	RENT-PMC-104	5	61	Cho thuê căn thông tầng Palm Garden không gian thoáng đãng	42000000.00	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-104; tầng 9, phòng 02.\nDiện tích: 140.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 5.60 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
62	RENT-SCV-101	5	62	Căn 2 phòng ngủ Scenic Valley Phú Mỹ Hưng đầy đủ nội thất xinh xắn	16000000.00	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-101; tầng 19, phòng 03.\nDiện tích: 70.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 4.20 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
63	RENT-SCV-102	5	63	Căn 2 phòng ngủ Scenic Valley hướng nhìn hồ bơi nội khu xanh mát	18000000.00	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-102; tầng 13, phòng 01.\nDiện tích: 80.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.60 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
64	RENT-SCV-103	5	64	Căn 3 phòng ngủ Scenic Valley Phú Mỹ Hưng căn góc hướng nhìn sân Golf	26000000.00	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-103; tầng 8, phòng 04.\nDiện tích: 110.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 7.70 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
65	RENT-SCV-104	5	65	Cho thuê căn 3 phòng ngủ Scenic Valley tầng cao thoáng mát đầy đủ nội thất	28000000.00	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-104; tầng 23, phòng 02.\nDiện tích: 130.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.50 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
66	RENT-SRC-101	5	66	Căn 1 phòng ngủ Sunrise City Central đầy đủ nội thất đẹp giá tốt	13000000.00	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-101; tầng 15, phòng 05.\nDiện tích: 56.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.48 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
67	RENT-SRC-102	5	67	Căn 2 phòng ngủ Sunrise City South tầng cao hướng nhìn trung tâm lộng lẫy	17500000.00	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-102; tầng 23, phòng 03.\nDiện tích: 76.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.80 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
68	RENT-SRC-103	5	68	Căn góc 3 phòng ngủ Sunrise City North thiết kế rộng rãi thoáng mát	23000000.00	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-103; tầng 17, phòng 02.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
69	RENT-SRC-104	5	69	Căn penthouse Sunrise City South diện tích lớn hướng nhìn 360 độ	55000000.00	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-104; tầng 30, phòng 04.\nDiện tích: 210.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 12.60 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
70	RENT-SSV-101	5	70	Biệt thự trên không Serenity Sky Villas 2 phòng ngủ hồ bơi riêng 136 m²	90000000.00	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-101; tầng 22, phòng 04.\nDiện tích: 136.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 8.16 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
71	RENT-SSV-102	5	71	Căn 3 phòng ngủ Serenity Sky Villas thông tầng trần cao 7m đẳng cấp	120000000.00	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-102; tầng 22, phòng 03.\nDiện tích: 210.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 16.80 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
72	RENT-SSV-103	5	72	Căn 4 phòng ngủ Serenity Sky Villas không gian sống riêng tư tuyệt đối	160000000.00	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-103; tầng 6, phòng 01.\nDiện tích: 330.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 19.80 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
73	RENT-SSV-104	5	73	Penthouse Serenity Sky Villas kiệt tác thượng lưu số 1 Sài Gòn	250000000.00	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-104; tầng 21, phòng 02.\nDiện tích: 500.00 m²; 5 phòng ngủ, 5 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 40.00 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
74	RENT-SWP-101	5	74	Căn 1 phòng ngủ Sunwah Pearl tháp White House đầy đủ nội thất siêu đẹp	20000000.00	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-101; tầng 4, phòng 01.\nDiện tích: 56.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.92 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
75	RENT-SWP-102	5	75	Cho thuê căn 2 phòng ngủ Sunwah Pearl tháp Silver House hướng nhìn sông cực phẩm	30000000.00	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-102; tầng 28, phòng 03.\nDiện tích: 102.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.08 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
76	RENT-SWP-103	5	76	Căn góc 3 phòng ngủ Sunwah Pearl tháp Golden House ngắm trọn Ba Son	48000000.00	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-103; tầng 4, phòng 04.\nDiện tích: 128.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.40 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
77	RENT-SWP-104	5	77	Penthouse Sunwah Pearl tầm nhìn ôm trọn sông Sài Gòn	110000000.00	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-104; tầng 18, phòng 02.\nDiện tích: 230.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 9.20 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
78	RENT-TGC-101	5	78	Căn 1 phòng ngủ Masteri Rise Mount The Global City thiết kế đẳng cấp	18000000.00	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-101; tầng 17, phòng 02.\nDiện tích: 50.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.00 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
79	RENT-TGC-102	5	79	Căn 2 phòng ngủ The Global City An Phú hướng nhìn kênh đào nhạc nước tuyệt đẹp	27000000.00	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-102; tầng 22, phòng 01.\nDiện tích: 75.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.00 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
80	RENT-TGC-103	5	80	Căn góc 3 phòng ngủ The Global City thiết kế thông minh full tiện nghi	38000000.00	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-103; tầng 14, phòng 04.\nDiện tích: 105.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.25 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
81	RENT-TGC-104	5	81	Cho thuê penthouse The Global City tầm nhìn biểu tượng vô tận	85000000.00	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-104; tầng 32, phòng 03.\nDiện tích: 190.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 7.60 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
82	RENT-TMQ-101	5	82	Căn 1 phòng ngủ The Marq Nguyễn Đình Chiểu đầy đủ nội thất hạng sang	28000000.00	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-101; tầng 2, phòng 01.\nDiện tích: 52.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.64 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
83	RENT-TMQ-102	5	83	Cho thuê căn 2 phòng ngủ The Marq Đa Kao hướng nhìn trung tâm thành phố	40000000.00	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-102; tầng 23, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.24 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
2	LIST-0002	5	2	Căn hộ 3 phòng ngủ Vinhomes Grand Park	5000000000.00	Căn hộ cần bán tại Vinhomes Grand Park - S9.01.\nMã căn: S9.01-1808; tầng 18, phòng 08.\nDiện tích: 75.20 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 12:56:50.41717	2027-01-09 12:56:50.41717	ACTIVE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	PUBLISHED	\N	\N	\N
84	RENT-TMQ-103	5	84	Căn 3 phòng ngủ The Marq sang trọng có sảnh thang máy riêng biệt	65000000.00	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-103; tầng 9, phòng 04.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
85	RENT-TMQ-104	5	85	Căn 4 phòng ngủ The Marq Đa Kao căn góc tầng cao cực đắt giá	100000000.00	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-104; tầng 2, phòng 02.\nDiện tích: 146.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.30 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
86	RENT-TRV-101	5	86	Căn 1 phòng ngủ The River Thủ Thiêm đầy đủ nội thất thiết kế hiện đại	24000000.00	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-101; tầng 17, phòng 04.\nDiện tích: 57.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.42 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
87	RENT-TRV-102	5	87	Căn 2 phòng ngủ The River Thủ Thiêm hướng nhìn trực diện sông lộng gió	36000000.00	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-102; tầng 19, phòng 03.\nDiện tích: 84.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.72 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
88	RENT-TRV-103	5	88	Căn 3 phòng ngủ The River Thủ Thiêm thang máy riêng nội thất siêu sang	62000000.00	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-103; tầng 14, phòng 01.\nDiện tích: 125.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 5.00 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
89	RENT-TRV-104	5	89	Căn biệt thự hồ bơi The River Thủ Thiêm có hồ bơi riêng xa hoa	130000000.00	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-104; tầng 13, phòng 02.\nDiện tích: 240.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 19.20 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
90	RENT-VCP-101	5	90	Căn 1 phòng ngủ Landmark 1 Vinhomes Central Park đầy đủ nội thất cao cấp	16500000.00	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-101; tầng 16, phòng 01.\nDiện tích: 54.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.78 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
91	RENT-VCP-102	5	91	Cho thuê căn 2 phòng ngủ Park 3 hướng nhìn trực diện công viên 14 ha lộng gió	23000000.00	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-102; tầng 6, phòng 02.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
92	RENT-VCP-103	5	92	Căn góc 3 phòng ngủ Central 2 Vinhomes Central Park nội thất nhập khẩu	35000000.00	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-103; tầng 9, phòng 04.\nDiện tích: 115.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.60 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
93	RENT-VCP-104	5	93	Cho thuê căn 4 phòng ngủ Landmark 81 tầng cao hướng nhìn toàn cảnh thành phố	70000000.00	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-104; tầng 13, phòng 03.\nDiện tích: 144.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 8.64 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
94	RENT-VGP-101	5	94	Cho thuê căn studio The Rainbow Vinhomes Grand Park đầy đủ nội thất	6500000.00	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-101; tầng 23, phòng 04.\nDiện tích: 33.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 1.32 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
20	RENT-EMP-102	5	20	Bán căn 2 phòng ngủ Tilia Empire City tầng cao hướng nhìn nội khu mát mẻ	17000000000.00	Căn hộ cần bán tại Empire City.\nMã căn: EMP-102; tầng 11, phòng 01.\nDiện tích: 93.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.72 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
30	RENT-GMS-104	5	30	Căn penthouse Masterise Grand Marina Bến Nghé siêu sang	175000000000.00	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-104; tầng 5, phòng 03.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
36	RENT-HDC-102	5	36	Bán căn 2 phòng ngủ2WC Hà Đô Centrosa tháp Orchid hướng nhìn hồ bơi	8250000000.00	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-102; tầng 18, phòng 02.\nDiện tích: 86.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 6.02 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
38	RENT-INF-101	5	38	Căn 1 phòng ngủ The Infiniti Riviera Point đầy đủ nội thất mới 100%	5250000000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-101; tầng 13, phòng 03.\nDiện tích: 58.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.64 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
39	RENT-INF-102	5	39	Bán căn 2 phòng ngủ Riviera Point hướng nhìn sông thoáng mát	7250000000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-102; tầng 21, phòng 01.\nDiện tích: 82.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 4.92 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	PUBLISHED	\N	\N	\N
95	RENT-VGP-102	5	95	Căn 2 phòng ngủ1WC The Origami Vinhomes Grand Park nội thất Nhật Bản	9000000.00	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-102; tầng 20, phòng 01.\nDiện tích: 59.00 m²; 2 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.54 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
96	RENT-VGP-103	5	96	Căn 2 phòng ngủ2WC Masteri Centre Point Vinhomes Grand Park cực sang	14000000.00	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-103; tầng 2, phòng 02.\nDiện tích: 72.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
97	RENT-VGP-104	5	97	Căn 3 phòng ngủ The Beverly Vinhomes Grand Park hướng nhìn trực diện công viên 36 ha	20000000.00	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-104; tầng 23, phòng 03.\nDiện tích: 100.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
98	RENT-VGR-101	5	98	Căn 1 phòng ngủ Aqua 1 Vinhomes Golden River đầy đủ nội thất sang trọng	21000000.00	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-101; tầng 8, phòng 01.\nDiện tích: 50.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.00 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
99	RENT-VGR-102	5	99	Cho thuê căn 2 phòng ngủ Lux 6 Vinhomes Golden River hướng nhìn trực diện sông	32000000.00	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-102; tầng 13, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
100	RENT-VGR-103	5	100	Căn góc 3 phòng ngủ Aqua 2 Vinhomes Golden River nội thất xa xỉ	50000000.00	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-103; tầng 17, phòng 02.\nDiện tích: 110.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.40 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
101	RENT-VGR-104	5	101	Căn 4 phòng ngủ penthouse Vinhomes Golden River đẳng cấp đỉnh cao	95000000.00	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-104; tầng 17, phòng 04.\nDiện tích: 160.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 11.20 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2026-10-11 15:43:02.119508	2027-10-11 15:43:02.119508	ACTIVE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	PUBLISHED	\N	\N	\N
\.


--
-- TOC entry 5588 (class 0 OID 27385)
-- Dependencies: 246
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (notification_id, user_id, title, message, notification_type, related_type, related_id, is_read, created_at, read_at) FROM stdin;
\.


--
-- TOC entry 5569 (class 0 OID 19608)
-- Dependencies: 226
-- Data for Name: owners; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.owners (owner_id, tax_code, identity_verified) FROM stdin;
5	0312345678	f
6	0312345679	f
\.


--
-- TOC entry 5576 (class 0 OID 19694)
-- Dependencies: 233
-- Data for Name: properties; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.properties (property_id, apartment_id, title, price, price_per_m2, description, address, status, created_at, updated_at, listing_type, is_illustrative, area, district) FROM stdin;
2	2	Căn hộ 3 phòng ngủ Vinhomes Grand Park	5000000000.00	66489361.70	Căn hộ cần bán tại Vinhomes Grand Park - S9.01.\nMã căn: S9.01-1808; tầng 18, phòng 08.\nDiện tích: 75.20 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	t	75.20	TP. Thủ Đức
3	3	Căn hộ 3 phòng ngủ Masteri Thảo Điền	9000000000.00	109356014.58	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MT-2506; tầng 25, phòng 06.\nDiện tích: 82.30 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.00 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh	RESERVED	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	t	82.30	TP. Thủ Đức
4	4	Căn hộ 2 phòng ngủ Masteri Thảo Điền	6500000000.00	98934550.99	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MT-1503; tầng 15, phòng 03.\nDiện tích: 65.70 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.00 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Thảo Điền, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	t	65.70	TP. Thủ Đức
5	5	Căn hộ 3 phòng ngủ Sunrise City	7000000000.00	77348066.30	Căn hộ cần bán tại Sunrise City.\nMã căn: SC-2001; tầng 20, phòng 01.\nDiện tích: 90.50 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 8.00 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 12:56:50.41717	2026-10-12 00:43:19.343717	SALE	t	90.50	Quận 7
1	1	Căn hộ 2 phòng ngủ Vinhomes Grand Park	3500000000.00	51094890.51	Căn hộ cần bán tại Vinhomes Grand Park - S9.01.\nMã căn: S9.01-1205; tầng 12, phòng 05.\nDiện tích: 68.50 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.20 m².\nĐịa chỉ: Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Nguyễn Xiển, Long Bình, Thủ Đức, TP. Hồ Chí Minh	SOLD	2026-10-11 12:56:50.41717	2026-10-12 00:33:02.787554	SALE	t	68.50	TP. Thủ Đức
24	57	Bán căn 2PN Estella Heights tháp T3 view hồ bơi tràn bờ	10500000000.00	116666666.67	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-102; tầng 9, phòng 02.\nDiện tích: 90.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.40 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	90.00	Quận 2
50	7	Bán căn Studio Masteri Thảo Điền T4 full nội thất xinh xắn	4500000000.00	93750000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-101; tầng 15, phòng 01.\nDiện tích: 48.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 2.88 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	48.00	Quận 2
6	85	Căn 2PN+1 Hà Đô Centrosa Garden góc 2 mặt thoáng cực rộng	9000000000.00	84112149.53	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-103; tầng 3, phòng 04.\nDiện tích: 107.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.28 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:33:02.787554	SALE	t	107.00	Quận 10
8	11	Căn 2PN City Garden tháp Crescent tầng cao view Landmark 81	10500000000.00	100000000.00	Căn hộ cần bán tại City Garden.\nMã căn: CTG-102; tầng 7, phòng 01.\nDiện tích: 105.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.25 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	105.00	Bình Thạnh
10	43	Penthouse City Garden thiết kế Duplex đỉnh cao kiến trúc	37500000000.00	170454545.45	Căn hộ cần bán tại City Garden.\nMã căn: CTG-104; tầng 15, phòng 04.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	220.00	Bình Thạnh
11	69	Căn 1PN tháp Hawaii Đảo Kim Cương view sông Sài Gòn êm đềm	6500000000.00	118181818.18	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-101; tầng 9, phòng 01.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.40 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	55.00	TP. Thủ Đức
12	84	Căn 2PN tháp Bora Bora Đảo Kim Cương full nội thất hiện đại	10500000000.00	119318181.82	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-102; tầng 2, phòng 02.\nDiện tích: 88.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.04 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	88.00	TP. Thủ Đức
13	91	Căn góc 3PN tháp Maldives Đảo Kim Cương view sông trực diện	16000000000.00	128000000.00	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-103; tầng 23, phòng 03.\nDiện tích: 125.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.25 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	125.00	TP. Thủ Đức
44	98	Căn góc 3PN Leman Luxury ban công thoáng mát nội thất xịn	17500000000.00	154867256.64	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-103; tầng 21, phòng 03.\nDiện tích: 113.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 7.91 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	113.00	Quận 3
45	34	Penthouse Leman Luxury tầng cao sân vườn riêng cực hiếm	47500000000.00	237500000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-104; tầng 10, phòng 02.\nDiện tích: 200.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 16.00 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	200.00	Quận 3
46	47	Căn 1PN The Grande Midtown Phú Mỹ Hưng thiết kế Nhật Bản	5750000000.00	92741935.48	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-101; tầng 23, phòng 03.\nDiện tích: 62.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.72 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	62.00	Quận 7
15	24	Căn 1PN Eco Green Sài Gòn Nguyễn Văn Linh full đồ xinh xắn	3250000000.00	72222222.22	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-101; tầng 5, phòng 03.\nDiện tích: 45.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	45.00	Quận 7
16	6	Căn 2PN Eco Green Sài Gòn view công viên Hương Tràm 22ha	4500000000.00	69230769.23	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-102; tầng 11, phòng 01.\nDiện tích: 65.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.25 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	65.00	Quận 7
17	13	Căn góc 3PN Eco Green Sài Gòn tầng cao view sông cầu Phú Mỹ	6500000000.00	76470588.24	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-103; tầng 27, phòng 02.\nDiện tích: 85.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.95 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	85.00	Quận 7
19	55	Căn 1PN Linden Empire City Thủ Thiêm full nội thất xịn	10500000000.00	164062500.00	Căn hộ cần bán tại Empire City.\nMã căn: EMP-101; tầng 9, phòng 02.\nDiện tích: 64.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.56 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	64.00	Quận 2
18	89	Căn 3PN Eco Green Sài Gòn full nội thất gỗ cao cấp	6500000000.00	68421052.63	Căn hộ cần bán tại Eco Green Sài Gòn.\nMã căn: EGR-104; tầng 31, phòng 04.\nDiện tích: 95.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 7.60 m².\nĐịa chỉ: 39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	39/1B Nguyễn Văn Linh, Phường Tân Thuận, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	95.00	Quận 7
47	23	Bán căn 2PN The Symphony Midtown view Sakura Park	8250000000.00	92696629.21	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-102; tầng 23, phòng 01.\nDiện tích: 89.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 6.23 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	89.00	Quận 7
41	66	Căn Duplex The Infiniti Riviera Point thiết kế thông tầng xa hoa	19500000000.00	130000000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-104; tầng 4, phòng 04.\nDiện tích: 150.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.50 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	150.00	Quận 7
21	67	Căn 3PN Cove Empire City view trực diện sông thang máy riêng	35000000000.00	225806451.61	Căn hộ cần bán tại Empire City.\nMã căn: EMP-103; tầng 3, phòng 03.\nDiện tích: 155.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 9.30 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	155.00	Quận 2
22	88	Penthouse Empire City Thủ Thiêm tầng cao view 360 độ cực phẩm	87500000000.00	397727272.73	Căn hộ cần bán tại Empire City.\nMã căn: EMP-104; tầng 6, phòng 04.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	220.00	Quận 2
23	70	Căn 1PN Estella Heights thiết kế nghỉ dưỡng full nội thất	7000000000.00	116666666.67	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-101; tầng 16, phòng 03.\nDiện tích: 60.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.40 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	60.00	Quận 2
25	78	Căn 3PN Estella Heights tầng cao view trọn thành phố lộng lẫy	15500000000.00	119230769.23	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-103; tầng 16, phòng 04.\nDiện tích: 130.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 9.10 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	130.00	Quận 2
26	27	Căn Penthouse Estella Heights sân vườn riêng đẳng cấp thượng lưu	37500000000.00	150000000.00	Căn hộ cần bán tại Estella Heights.\nMã căn: ESH-104; tầng 23, phòng 01.\nDiện tích: 250.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 15.00 m².\nĐịa chỉ: 88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	88 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	250.00	Quận 2
32	97	Căn 2PN Gateway Thảo Điền tầng cao view sông Sài Gòn tuyệt đẹp	10500000000.00	123529411.76	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-102; tầng 15, phòng 04.\nDiện tích: 85.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 5.10 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	85.00	Quận 2
33	19	Căn 3PN Gateway Thảo Điền thiết kế sang trọng nội thất cao cấp	16000000000.00	131147540.98	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-103; tầng 9, phòng 01.\nDiện tích: 122.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 9.76 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	122.00	Quận 2
34	22	Căn Garden Villa Gateway Thảo Điền có sân vườn rộng thoáng	40000000000.00	222222222.22	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-104; tầng 12, phòng 02.\nDiện tích: 180.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 10.80 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	180.00	Quận 2
48	48	Căn góc 3PN The Signature Midtown tầng trung view sông biệt thự	12000000000.00	99173553.72	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-103; tầng 2, phòng 04.\nDiện tích: 121.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 8.47 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	121.00	Quận 7
49	33	Căn 4PN The Peak Midtown Phú Mỹ Hưng full nội thất cao cấp	21500000000.00	134375000.00	Căn hộ cần bán tại Midtown Phú Mỹ Hưng.\nMã căn: MDT-104; tầng 9, phòng 02.\nDiện tích: 160.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 11.20 m².\nĐịa chỉ: Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Đường Nguyễn Lương Bằng, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	160.00	Quận 7
28	60	Bán căn 2PN Grand Marina Saigon view sông cực đẹp	39000000000.00	443181818.18	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-102; tầng 8, phòng 01.\nDiện tích: 88.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.52 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	88.00	Quận 1
31	63	Bán căn 1PN Gateway Thảo Điền full nội thất hiện đại	7000000000.00	134615384.62	Căn hộ cần bán tại The Gateway Thảo Điền.\nMã căn: GTW-101; tầng 11, phòng 03.\nDiện tích: 52.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.64 m².\nĐịa chỉ: 2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Trần Ngọc Diện, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	52.00	Quận 2
7	15	Căn 1PN City Garden Bình Thạnh thiết kế gợn sóng độc đáo	6500000000.00	92857142.86	Căn hộ cần bán tại City Garden.\nMã căn: CTG-101; tầng 17, phòng 02.\nDiện tích: 70.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 2.80 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	70.00	Bình Thạnh
9	16	Căn 3PN City Garden nội thất Châu Âu thiết kế cực sang	16000000000.00	114285714.29	Căn hộ cần bán tại City Garden.\nMã căn: CTG-103; tầng 6, phòng 03.\nDiện tích: 140.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.00 m².\nĐịa chỉ: 59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	59 Ngô Tất Tố, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	140.00	Bình Thạnh
36	28	Bán căn 2PN2WC Hà Đô Centrosa tháp Orchid view hồ bơi	8250000000.00	95930232.56	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-102; tầng 18, phòng 02.\nDiện tích: 86.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 6.02 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	86.00	Quận 10
39	52	Bán căn 2PN Riviera Point view sông thoáng mát	7250000000.00	88414634.15	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-102; tầng 21, phòng 01.\nDiện tích: 82.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 4.92 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	82.00	Quận 7
51	9	Căn hộ 2PN2WC Masteri Thảo Điền T2 view sông Sài Gòn thoáng mát	6500000000.00	95588235.29	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-102; tầng 11, phòng 02.\nDiện tích: 68.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 5.44 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	68.00	Quận 2
14	92	Căn Pool Villa Đảo Kim Cương sân vườn hồ bơi riêng xa xỉ	47500000000.00	226190476.19	Căn hộ cần bán tại Đảo Kim Cương (Diamond Island).\nMã căn: DMI-104; tầng 2, phòng 04.\nDiện tích: 210.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 12.60 m².\nĐịa chỉ: Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Số 1 Đường số 104, Phường Bình Trưng, Thủ Đức, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	210.00	TP. Thủ Đức
27	74	Căn 1PN Tòa Lake Grand Marina Saigon quản lý chuẩn Marriott	22000000000.00	372881355.93	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-101; tầng 16, phòng 02.\nDiện tích: 59.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.72 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	59.00	Quận 1
29	94	Căn 3PN Hàng hiệu Marriott Grand Marina view trung tâm Q1	62500000000.00	469924812.03	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-103; tầng 12, phòng 04.\nDiện tích: 133.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 10.64 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	133.00	Quận 1
52	80	Căn góc 3PN Masteri Thảo Điền T1 tầng cao view Vincom sang trọng	9000000000.00	100000000.00	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-103; tầng 4, phòng 03.\nDiện tích: 90.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	90.00	Quận 2
53	86	Bán Duplex Masteri Thảo Điền thiết kế hiện đại, đầy đủ tiện nghi	18000000000.00	138461538.46	Căn hộ cần bán tại Masteri Thảo Điền.\nMã căn: MST-104; tầng 10, phòng 04.\nDiện tích: 130.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.50 m².\nĐịa chỉ: 159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	159 Xa Lộ Hà Nội, Phường Thảo Điền, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	130.00	Quận 2
37	20	Căn 3PN Hà Đô Centrosa Garden tầng cao view trọn thành phố	12000000000.00	97560975.61	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-104; tầng 16, phòng 01.\nDiện tích: 123.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.92 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	123.00	Quận 10
30	93	Căn Penthouse Masterise Grand Marina Bến Nghé siêu sang	175000000000.00	795454545.45	Căn hộ cần bán tại Grand Marina Sài Gòn.\nMã căn: GMS-104; tầng 5, phòng 03.\nDiện tích: 220.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 15.40 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:33:02.787554	SALE	t	220.00	Quận 1
20	45	Bán căn 2PN Tilia Empire City tầng cao view nội khu mát mẻ	17000000000.00	182795698.92	Căn hộ cần bán tại Empire City.\nMã căn: EMP-102; tầng 11, phòng 01.\nDiện tích: 93.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.72 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:36:46.174464	SALE	t	93.00	Quận 2
42	99	Căn 2PN Leman Luxury Nguyễn Đình Chiểu full nội thất Thụy Sỹ	10500000000.00	140000000.00	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-101; tầng 5, phòng 04.\nDiện tích: 75.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	75.00	Quận 3
43	10	Bán căn 3PN Leman Luxury không gian sống yên tĩnh đẳng cấp	16000000000.00	166666666.67	Căn hộ cần bán tại Leman Luxury Apartments.\nMã căn: LMN-102; tầng 3, phòng 01.\nDiện tích: 96.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.84 m².\nĐịa chỉ: 117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	117 Nguyễn Đình Chiểu, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	96.00	Quận 3
40	53	Căn góc 3PN Riviera Point tầng cao view toàn cảnh Quận 7	10500000000.00	87500000.00	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-103; tầng 5, phòng 02.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 8.40 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:43:19.343717	SALE	t	120.00	Quận 7
54	81	Căn 1PN Galleria Metropole Thủ Thiêm full nội thất cao cấp	25000000.00	\N	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-101; tầng 9, phòng 03.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 2.75 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	55.00	Quận 2
55	73	Cho thuê căn 2PN The Crest Metropole view cầu Ba Sơn tuyệt đẹp	38000000.00	\N	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-102; tầng 9, phòng 02.\nDiện tích: 82.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.74 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	82.00	Quận 2
56	51	Căn 3PN Opera Metropole Thủ Thiêm ban công rộng view sông	60000000.00	\N	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-103; tầng 23, phòng 01.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	120.00	Quận 2
57	90	Căn 4PN VIP Metropole Thủ Thiêm thang máy riêng biệt xa hoa	110000000.00	\N	Căn hộ cho thuê tại The Metropole Thủ Thiêm.\nMã căn: MTP-104; tầng 16, phòng 04.\nDiện tích: 170.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 6.80 m².\nĐịa chỉ: Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Khu đô thị mới Thủ Thiêm, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	170.00	Quận 2
58	12	Căn 1PN Palm Heights An Phú full nội thất xinh xắn	14000000.00	\N	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-101; tầng 2, phòng 01.\nDiện tích: 55.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.30 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	55.00	Quận 2
59	61	Căn 2PN Palm Heights view sông mát mẻ tầng cao	18500000.00	\N	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-102; tầng 9, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	78.00	Quận 2
60	82	Căn góc 3PN Palm Heights diện tích rộng full đồ cao cấp	25000000.00	\N	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-103; tầng 16, phòng 04.\nDiện tích: 105.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 6.30 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	105.00	Quận 2
61	25	Cho thuê căn Duplex Palm Garden không gian thoáng đãng	42000000.00	\N	Căn hộ cho thuê tại Palm Heights / Palm City.\nMã căn: PMC-104; tầng 9, phòng 02.\nDiện tích: 140.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 5.60 m².\nĐịa chỉ: Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Song Hành, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	140.00	Quận 2
62	32	Căn 2PN Scenic Valley Phú Mỹ Hưng full nội thất xinh xắn	16000000.00	\N	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-101; tầng 19, phòng 03.\nDiện tích: 70.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 4.20 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	70.00	Quận 7
63	18	Căn 2PN Scenic Valley view hồ bơi nội khu xanh mát	18000000.00	\N	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-102; tầng 13, phòng 01.\nDiện tích: 80.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 5.60 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	80.00	Quận 7
64	83	Căn 3PN Scenic Valley Phú Mỹ Hưng căn góc view sân Golf	26000000.00	\N	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-103; tầng 8, phòng 04.\nDiện tích: 110.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 7.70 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	110.00	Quận 7
65	26	Cho thuê căn 3PN Scenic Valley tầng cao thoáng mát full đồ	28000000.00	\N	Căn hộ cho thuê tại Scenic Valley.\nMã căn: SCV-104; tầng 23, phòng 02.\nDiện tích: 130.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.50 m².\nĐịa chỉ: Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Tôn Dật Tiên, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	130.00	Quận 7
66	49	Căn 1PN Sunrise City Central full nội thất đẹp giá tốt	13000000.00	\N	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-101; tầng 15, phòng 05.\nDiện tích: 56.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.48 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	56.00	Quận 7
67	36	Căn 2PN Sunrise City South tầng cao view trung tâm lộng lẫy	17500000.00	\N	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-102; tầng 23, phòng 03.\nDiện tích: 76.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.80 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	76.00	Quận 7
68	21	Căn góc 3PN Sunrise City North thiết kế rộng rãi thoáng mát	23000000.00	\N	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-103; tầng 17, phòng 02.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	120.00	Quận 7
69	37	Căn Penthouse Sunrise City South diện tích lớn view 360 độ	55000000.00	\N	Căn hộ cho thuê tại Sunrise City.\nMã căn: SRC-104; tầng 30, phòng 04.\nDiện tích: 210.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 12.60 m².\nĐịa chỉ: 23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	23 Nguyễn Hữu Thọ, Tân Hưng, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	210.00	Quận 7
70	62	Biệt thự trên không Serenity Sky Villas 2PN hồ bơi riêng 136m2	90000000.00	\N	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-101; tầng 22, phòng 04.\nDiện tích: 136.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 8.16 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	136.00	Quận 3
71	39	Căn 3PN Serenity Sky Villas thông tầng trần cao 7m đẳng cấp	120000000.00	\N	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-102; tầng 22, phòng 03.\nDiện tích: 210.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 16.80 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	210.00	Quận 3
72	17	Căn 4PN Serenity Sky Villas không gian sống riêng tư tuyệt đối	160000000.00	\N	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-103; tầng 6, phòng 01.\nDiện tích: 330.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 19.80 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	330.00	Quận 3
73	29	Penthouse Serenity Sky Villas kiệt tác thượng lưu số 1 Sài Gòn	250000000.00	\N	Căn hộ cho thuê tại Serenity Sky Villas.\nMã căn: SSV-104; tầng 21, phòng 02.\nDiện tích: 500.00 m²; 5 phòng ngủ, 5 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 40.00 m².\nĐịa chỉ: 259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	259 Điện Biên Phủ, Phường Xuân Khánh, Quận 3, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	500.00	Quận 3
74	38	Căn 1PN Sunwah Pearl tháp White House full đồ siêu đẹp	20000000.00	\N	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-101; tầng 4, phòng 01.\nDiện tích: 56.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.92 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	56.00	Bình Thạnh
75	65	Cho thuê căn 2PN Sunwah Pearl tháp Silver House view sông cực phẩm	30000000.00	\N	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-102; tầng 28, phòng 03.\nDiện tích: 102.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.08 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	102.00	Bình Thạnh
76	71	Căn góc 3PN Sunwah Pearl tháp Golden House ngắm trọn Bason	48000000.00	\N	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-103; tầng 4, phòng 04.\nDiện tích: 128.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.40 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	128.00	Bình Thạnh
77	40	Penthouse Sunwah Pearl tầm nhìn ôm trọn sông Sài Gòn	110000000.00	\N	Căn hộ cho thuê tại Sunwah Pearl.\nMã căn: SWP-104; tầng 18, phòng 02.\nDiện tích: 230.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 9.20 m².\nĐịa chỉ: 90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	90 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	230.00	Bình Thạnh
88	30	Căn 3PN The River Thủ Thiêm thang máy riêng nội thất siêu sang	62000000.00	\N	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-103; tầng 14, phòng 01.\nDiện tích: 125.00 m²; 3 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 5.00 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	125.00	Quận 2
78	54	Căn 1PN Masteri Rise Mount The Global City thiết kế đẳng cấp	18000000.00	\N	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-101; tầng 17, phòng 02.\nDiện tích: 50.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.00 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	50.00	Quận 2
79	50	Căn 2PN The Global City An Phú view kênh đào nhạc nước tuyệt đẹp	27000000.00	\N	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-102; tầng 22, phòng 01.\nDiện tích: 75.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 3.00 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	75.00	Quận 2
80	96	Căn góc 3PN The Global City thiết kế thông minh full tiện nghi	38000000.00	\N	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-103; tầng 14, phòng 04.\nDiện tích: 105.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 5.25 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	105.00	Quận 2
81	75	Cho thuê Penthouse The Global City tầm nhìn biểu tượng vô tận	85000000.00	\N	Căn hộ cho thuê tại The Global City.\nMã căn: TGC-104; tầng 32, phòng 03.\nDiện tích: 190.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 7.60 m².\nĐịa chỉ: Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Đỗ Xuân Hợp, Phường An Phú, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	190.00	Quận 2
82	8	Căn 1PN The Marq Nguyễn Đình Chiểu full nội thất hạng sang	28000000.00	\N	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-101; tầng 2, phòng 01.\nDiện tích: 52.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.64 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	52.00	Quận 1
83	79	Cho thuê căn 2PN The Marq Đa Kao view trung tâm thành phố	40000000.00	\N	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-102; tầng 23, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.24 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	78.00	Quận 1
84	101	Căn 3PN The Marq sang trọng có sảnh thang máy riêng biệt	65000000.00	\N	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-103; tầng 9, phòng 04.\nDiện tích: 120.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	120.00	Quận 1
85	56	Căn 4PN The Marq Đa Kao căn góc tầng cao cực đắt giá	100000000.00	\N	Căn hộ cho thuê tại The Marq.\nMã căn: TMQ-104; tầng 2, phòng 02.\nDiện tích: 146.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 7.30 m².\nĐịa chỉ: 29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	29B Nguyễn Đình Chiểu, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	146.00	Quận 1
86	87	Căn 1PN The River Thủ Thiêm full nội thất thiết kế hiện đại	24000000.00	\N	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-101; tầng 17, phòng 04.\nDiện tích: 57.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.42 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	57.00	Quận 2
87	59	Căn 2PN The River Thủ Thiêm view trực diện sông lộng gió	36000000.00	\N	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-102; tầng 19, phòng 03.\nDiện tích: 84.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 6.72 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	84.00	Quận 2
89	44	Căn Pool Villa The River Thủ Thiêm có hồ bơi riêng xa hoa	130000000.00	\N	Căn hộ cho thuê tại The River Thủ Thiêm.\nMã căn: TRV-104; tầng 13, phòng 02.\nDiện tích: 240.00 m²; 4 phòng ngủ, 4 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 19.20 m².\nĐịa chỉ: Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đại lộ Trống Đồng, Phường Thủ Thiêm, Quận 2, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	240.00	Quận 2
90	68	Căn 1PN Landmark 1 Vinhomes Central Park full nội thất cao cấp	16500000.00	\N	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-101; tầng 16, phòng 01.\nDiện tích: 54.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 3.78 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	54.00	Bình Thạnh
91	76	Cho thuê căn 2PN Park 3 view trực diện công viên 14ha lộng gió	23000000.00	\N	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-102; tầng 6, phòng 02.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	78.00	Bình Thạnh
92	100	Căn góc 3PN Central 2 Vinhomes Central Park nội thất nhập khẩu	35000000.00	\N	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-103; tầng 9, phòng 04.\nDiện tích: 115.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông Nam; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.60 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	115.00	Bình Thạnh
93	77	Cho thuê căn 4PN Landmark 81 tầng cao view toàn cảnh thành phố	70000000.00	\N	Căn hộ cho thuê tại Vinhomes Central Park.\nMã căn: VCP-104; tầng 13, phòng 03.\nDiện tích: 144.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Đông Bắc; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 8.64 m².\nĐịa chỉ: 208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	208 Nguyễn Hữu Cảnh, Phường Thạnh Mỹ Tây, Bình Thạnh, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	144.00	Bình Thạnh
94	95	Cho thuê căn Studio The Rainbow Vinhomes Grand Park full đồ	6500000.00	\N	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-101; tầng 23, phòng 04.\nDiện tích: 33.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 1.32 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	33.00	Quận 9
95	42	Căn 2PN1WC The Origami Vinhomes Grand Park nội thất Nhật Bản	9000000.00	\N	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-102; tầng 20, phòng 01.\nDiện tích: 59.00 m²; 2 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 3.54 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	59.00	Quận 9
96	46	Căn 2PN2WC Masteri Centre Point Vinhomes Grand Park cực sang	14000000.00	\N	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-103; tầng 2, phòng 02.\nDiện tích: 72.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.60 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	72.00	Quận 9
97	72	Căn 3PN The Beverly Vinhomes Grand Park view trực diện công viên 36ha	20000000.00	\N	Căn hộ cho thuê tại Vinhomes Grand Park.\nMã căn: VGP-104; tầng 23, phòng 03.\nDiện tích: 100.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn nội khu.\nDiện tích ban công: 6.00 m².\nĐịa chỉ: Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	Đường Nguyễn Xiển, Phường Long Bình, Quận 9, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	100.00	Quận 9
98	14	Căn 1PN Aqua 1 Vinhomes Golden River full đồ sang trọng	21000000.00	\N	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-101; tầng 8, phòng 01.\nDiện tích: 50.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Nam; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.00 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	50.00	Quận 1
99	41	Cho thuê căn 2PN Lux 6 Vinhomes Golden River view trực diện sông	32000000.00	\N	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-102; tầng 13, phòng 03.\nDiện tích: 78.00 m²; 2 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Tây; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 3.90 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	78.00	Quận 1
100	35	Căn góc 3PN Aqua 2 Vinhomes Golden River nội thất xa xỉ	50000000.00	\N	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-103; tầng 17, phòng 02.\nDiện tích: 110.00 m²; 3 phòng ngủ, 2 phòng tắm.\nHướng căn hộ: Bắc; tầm nhìn: Hướng nhìn thành phố.\nDiện tích ban công: 4.40 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	110.00	Quận 1
101	58	Căn 4PN Penthouse Vinhomes Golden River đẳng cấp đỉnh cao	95000000.00	\N	Căn hộ cho thuê tại Vinhomes Golden River (Ba Son).\nMã căn: VGR-104; tầng 17, phòng 04.\nDiện tích: 160.00 m²; 4 phòng ngủ, 3 phòng tắm.\nHướng căn hộ: Nam; tầm nhìn: Hướng nhìn hồ bơi.\nDiện tích ban công: 11.20 m².\nĐịa chỉ: 2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh.\nPháp lý: Hợp đồng cho thuê.	2 Tôn Đức Thắng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-11 15:43:02.119508	RENT	t	160.00	Quận 1
35	31	Căn 1PN1WC Hà Đô Centrosa Garden full nội thất hiện đại	5750000000.00	108490566.04	Căn hộ cần bán tại Hà Đô Centrosa Garden.\nMã căn: HDC-101; tầng 3, phòng 03.\nDiện tích: 53.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Tây Bắc; tầm nhìn: Hướng nhìn công viên.\nDiện tích ban công: 2.65 m².\nĐịa chỉ: 200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	200 3 Tháng 2, Phường Hòa Hưng, Quận 10, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	53.00	Quận 10
38	64	Căn 1PN The Infiniti Riviera Point full nội thất mới 100%	5250000000.00	90517241.38	Căn hộ cần bán tại The Infiniti at Riviera Point.\nMã căn: INF-101; tầng 13, phòng 03.\nDiện tích: 58.00 m²; 1 phòng ngủ, 1 phòng tắm.\nHướng căn hộ: Đông; tầm nhìn: Hướng nhìn ra sông.\nDiện tích ban công: 4.64 m².\nĐịa chỉ: 584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh.\nPháp lý: Sổ hồng/Sổ đỏ.	584 Huỳnh Tấn Phát, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh	AVAILABLE	2026-10-11 15:43:02.119508	2026-10-12 00:40:34.063806	SALE	t	58.00	Quận 7
\.


--
-- TOC entry 5580 (class 0 OID 19766)
-- Dependencies: 237
-- Data for Name: property_images; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.property_images (image_id, property_id, image_url, is_thumbnail, uploaded_at) FROM stdin;
7	7	images/rentals/rental_22.jpg	1	2026-10-11 15:43:02.119508
8	7	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
9	7	images/rentals/rental_16.jpg	0	2026-10-11 15:43:02.119508
10	8	images/rentals/rental_01.jpg	1	2026-10-11 15:43:02.119508
11	8	images/rentals/rental_08.jpg	0	2026-10-11 15:43:02.119508
12	9	images/rentals/rental_28.jpg	1	2026-10-11 15:43:02.119508
13	9	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
14	10	images/rentals/rental_13.jpg	1	2026-10-11 15:43:02.119508
15	10	images/rentals/rental_16.jpg	0	2026-10-11 15:43:02.119508
16	10	images/rentals/rental_22.jpg	0	2026-10-11 15:43:02.119508
17	11	images/rentals/rental_03.jpg	1	2026-10-11 15:43:02.119508
18	11	images/rentals/rental_29.jpg	0	2026-10-11 15:43:02.119508
19	12	images/rentals/rental_21.jpg	1	2026-10-11 15:43:02.119508
20	12	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
21	13	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
22	13	images/rentals/rental_30.jpg	0	2026-10-11 15:43:02.119508
23	13	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
24	14	images/rentals/rental_14.jpg	1	2026-10-11 15:43:02.119508
25	14	images/rentals/rental_29.jpg	0	2026-10-11 15:43:02.119508
26	15	images/rentals/rental_21.jpg	1	2026-10-11 15:43:02.119508
27	15	images/rentals/rental_25.jpg	0	2026-10-11 15:43:02.119508
28	16	images/rentals/rental_27.jpg	1	2026-10-11 15:43:02.119508
29	16	images/rentals/rental_17.jpg	0	2026-10-11 15:43:02.119508
30	16	images/rentals/rental_20.jpg	0	2026-10-11 15:43:02.119508
31	17	images/rentals/rental_11.jpg	1	2026-10-11 15:43:02.119508
32	17	images/rentals/rental_29.jpg	0	2026-10-11 15:43:02.119508
33	18	images/rentals/rental_06.jpg	1	2026-10-11 15:43:02.119508
34	18	images/rentals/rental_23.jpg	0	2026-10-11 15:43:02.119508
35	19	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
36	19	images/rentals/rental_28.jpg	0	2026-10-11 15:43:02.119508
37	19	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
38	20	images/rentals/rental_08.jpg	1	2026-10-11 15:43:02.119508
39	20	images/rentals/rental_02.jpg	0	2026-10-11 15:43:02.119508
40	21	images/rentals/rental_19.jpg	1	2026-10-11 15:43:02.119508
41	21	images/rentals/rental_07.jpg	0	2026-10-11 15:43:02.119508
42	22	images/rentals/rental_21.jpg	1	2026-10-11 15:43:02.119508
43	22	images/rentals/rental_04.jpg	0	2026-10-11 15:43:02.119508
44	22	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
45	23	images/rentals/rental_13.jpg	1	2026-10-11 15:43:02.119508
46	23	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
47	24	images/rentals/rental_09.jpg	1	2026-10-11 15:43:02.119508
48	24	images/rentals/rental_12.jpg	0	2026-10-11 15:43:02.119508
49	25	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
50	25	images/rentals/rental_24.jpg	0	2026-10-11 15:43:02.119508
51	25	images/rentals/rental_28.jpg	0	2026-10-11 15:43:02.119508
52	26	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
53	26	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
54	27	images/rentals/rental_11.jpg	1	2026-10-11 15:43:02.119508
55	27	images/rentals/rental_10.jpg	0	2026-10-11 15:43:02.119508
56	28	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
57	28	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
58	28	images/rentals/rental_13.jpg	0	2026-10-11 15:43:02.119508
59	29	images/rentals/rental_23.jpg	1	2026-10-11 15:43:02.119508
60	29	images/rentals/rental_25.jpg	0	2026-10-11 15:43:02.119508
61	30	images/rentals/rental_06.jpg	1	2026-10-11 15:43:02.119508
62	30	images/rentals/rental_23.jpg	0	2026-10-11 15:43:02.119508
63	31	images/rentals/rental_30.jpg	1	2026-10-11 15:43:02.119508
64	31	images/rentals/rental_16.jpg	0	2026-10-11 15:43:02.119508
65	31	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
66	32	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
67	32	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
68	33	images/rentals/rental_21.jpg	1	2026-10-11 15:43:02.119508
69	33	images/rentals/rental_04.jpg	0	2026-10-11 15:43:02.119508
70	34	images/rentals/rental_03.jpg	1	2026-10-11 15:43:02.119508
71	34	images/rentals/rental_14.jpg	0	2026-10-11 15:43:02.119508
72	34	images/rentals/rental_29.jpg	0	2026-10-11 15:43:02.119508
73	35	images/rentals/rental_17.jpg	1	2026-10-11 15:43:02.119508
74	35	images/rentals/rental_20.jpg	0	2026-10-11 15:43:02.119508
75	36	images/rentals/rental_28.jpg	1	2026-10-11 15:43:02.119508
76	36	images/rentals/rental_24.jpg	0	2026-10-11 15:43:02.119508
77	6	images/rentals/rental_02.jpg	1	2026-10-11 15:43:02.119508
78	6	images/rentals/rental_01.jpg	0	2026-10-11 15:43:02.119508
79	6	images/rentals/rental_08.jpg	0	2026-10-11 15:43:02.119508
80	37	images/rentals/rental_11.jpg	1	2026-10-11 15:43:02.119508
81	37	images/rentals/rental_10.jpg	0	2026-10-11 15:43:02.119508
82	38	images/rentals/rental_19.jpg	1	2026-10-11 15:43:02.119508
83	38	images/rentals/rental_07.jpg	0	2026-10-11 15:43:02.119508
84	39	images/rentals/rental_17.jpg	1	2026-10-11 15:43:02.119508
85	39	images/rentals/rental_27.jpg	0	2026-10-11 15:43:02.119508
86	39	images/rentals/rental_20.jpg	0	2026-10-11 15:43:02.119508
87	40	images/rentals/rental_09.jpg	1	2026-10-11 15:43:02.119508
88	40	images/rentals/rental_12.jpg	0	2026-10-11 15:43:02.119508
89	41	images/rentals/rental_04.jpg	1	2026-10-11 15:43:02.119508
90	41	images/rentals/rental_21.jpg	0	2026-10-11 15:43:02.119508
91	42	images/rentals/rental_02.jpg	1	2026-10-11 15:43:02.119508
92	42	images/rentals/rental_08.jpg	0	2026-10-11 15:43:02.119508
93	42	images/rentals/rental_01.jpg	0	2026-10-11 15:43:02.119508
94	43	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
95	43	images/rentals/rental_03.jpg	0	2026-10-11 15:43:02.119508
96	44	images/rentals/rental_13.jpg	1	2026-10-11 15:43:02.119508
97	44	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
2	1	images/rentals/rental_22.jpg	0	2026-10-11 12:56:50.41717
5	4	images/rentals/rental_29.jpg	1	2026-10-11 12:56:50.41717
6	5	images/rentals/rental_03.jpg	1	2026-10-11 12:56:50.41717
98	45	images/rentals/rental_27.jpg	1	2026-10-11 15:43:02.119508
99	45	images/rentals/rental_20.jpg	0	2026-10-11 15:43:02.119508
100	45	images/rentals/rental_17.jpg	0	2026-10-11 15:43:02.119508
101	46	images/rentals/rental_09.jpg	1	2026-10-11 15:43:02.119508
102	46	images/rentals/rental_12.jpg	0	2026-10-11 15:43:02.119508
103	47	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
104	47	images/rentals/rental_14.jpg	0	2026-10-11 15:43:02.119508
105	48	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
106	48	images/rentals/rental_30.jpg	0	2026-10-11 15:43:02.119508
107	48	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
108	49	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
109	49	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
110	50	images/rentals/rental_23.jpg	1	2026-10-11 15:43:02.119508
111	50	images/rentals/rental_06.jpg	0	2026-10-11 15:43:02.119508
112	51	images/rentals/rental_24.jpg	1	2026-10-11 15:43:02.119508
113	51	images/rentals/rental_28.jpg	0	2026-10-11 15:43:02.119508
114	51	images/rentals/rental_07.jpg	0	2026-10-11 15:43:02.119508
115	52	images/rentals/rental_22.jpg	1	2026-10-11 15:43:02.119508
116	52	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
117	53	images/rentals/rental_11.jpg	1	2026-10-11 15:43:02.119508
118	53	images/rentals/rental_10.jpg	0	2026-10-11 15:43:02.119508
119	54	images/rentals/rental_25.jpg	1	2026-10-11 15:43:02.119508
120	54	images/rentals/rental_04.jpg	0	2026-10-11 15:43:02.119508
121	54	images/rentals/rental_21.jpg	0	2026-10-11 15:43:02.119508
122	55	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
123	55	images/rentals/rental_19.jpg	0	2026-10-11 15:43:02.119508
124	56	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
125	56	images/rentals/rental_14.jpg	0	2026-10-11 15:43:02.119508
126	57	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
127	57	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
128	57	images/rentals/rental_22.jpg	0	2026-10-11 15:43:02.119508
129	58	images/rentals/rental_28.jpg	1	2026-10-11 15:43:02.119508
130	58	images/rentals/rental_24.jpg	0	2026-10-11 15:43:02.119508
131	59	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
132	59	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
133	60	images/rentals/rental_23.jpg	1	2026-10-11 15:43:02.119508
134	60	images/rentals/rental_25.jpg	0	2026-10-11 15:43:02.119508
135	60	images/rentals/rental_06.jpg	0	2026-10-11 15:43:02.119508
136	61	images/rentals/rental_11.jpg	1	2026-10-11 15:43:02.119508
137	61	images/rentals/rental_10.jpg	0	2026-10-11 15:43:02.119508
138	62	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
139	62	images/rentals/rental_19.jpg	0	2026-10-11 15:43:02.119508
140	63	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
141	63	images/rentals/rental_30.jpg	0	2026-10-11 15:43:02.119508
142	63	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
143	64	images/rentals/rental_08.jpg	1	2026-10-11 15:43:02.119508
144	64	images/rentals/rental_02.jpg	0	2026-10-11 15:43:02.119508
145	65	images/rentals/rental_12.jpg	1	2026-10-11 15:43:02.119508
146	65	images/rentals/rental_09.jpg	0	2026-10-11 15:43:02.119508
147	66	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
148	66	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
149	66	images/rentals/rental_13.jpg	0	2026-10-11 15:43:02.119508
150	67	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
151	67	images/rentals/rental_03.jpg	0	2026-10-11 15:43:02.119508
152	68	images/rentals/rental_20.jpg	1	2026-10-11 15:43:02.119508
153	68	images/rentals/rental_27.jpg	0	2026-10-11 15:43:02.119508
154	69	images/rentals/rental_01.jpg	1	2026-10-11 15:43:02.119508
155	69	images/rentals/rental_08.jpg	0	2026-10-11 15:43:02.119508
156	69	images/rentals/rental_02.jpg	0	2026-10-11 15:43:02.119508
157	70	images/rentals/rental_28.jpg	1	2026-10-11 15:43:02.119508
158	70	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
159	71	images/rentals/rental_15.jpg	1	2026-10-11 15:43:02.119508
160	71	images/rentals/rental_30.jpg	0	2026-10-11 15:43:02.119508
161	72	images/rentals/rental_25.jpg	1	2026-10-11 15:43:02.119508
162	72	images/rentals/rental_23.jpg	0	2026-10-11 15:43:02.119508
163	72	images/rentals/rental_06.jpg	0	2026-10-11 15:43:02.119508
164	73	images/rentals/rental_20.jpg	1	2026-10-11 15:43:02.119508
165	73	images/rentals/rental_17.jpg	0	2026-10-11 15:43:02.119508
166	74	images/rentals/rental_08.jpg	1	2026-10-11 15:43:02.119508
167	74	images/rentals/rental_01.jpg	0	2026-10-11 15:43:02.119508
168	75	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
169	75	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
170	75	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
171	76	images/rentals/rental_24.jpg	1	2026-10-11 15:43:02.119508
172	76	images/rentals/rental_28.jpg	0	2026-10-11 15:43:02.119508
173	77	images/rentals/rental_27.jpg	1	2026-10-11 15:43:02.119508
174	77	images/rentals/rental_20.jpg	0	2026-10-11 15:43:02.119508
175	78	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
176	78	images/rentals/rental_03.jpg	0	2026-10-11 15:43:02.119508
177	78	images/rentals/rental_14.jpg	0	2026-10-11 15:43:02.119508
178	79	images/rentals/rental_10.jpg	1	2026-10-11 15:43:02.119508
179	79	images/rentals/rental_11.jpg	0	2026-10-11 15:43:02.119508
180	80	images/rentals/rental_13.jpg	1	2026-10-11 15:43:02.119508
181	80	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
182	81	images/rentals/rental_18.jpg	1	2026-10-11 15:43:02.119508
183	81	images/rentals/rental_04.jpg	0	2026-10-11 15:43:02.119508
184	81	images/rentals/rental_21.jpg	0	2026-10-11 15:43:02.119508
185	82	images/rentals/rental_19.jpg	1	2026-10-11 15:43:02.119508
186	82	images/rentals/rental_07.jpg	0	2026-10-11 15:43:02.119508
187	83	images/rentals/rental_09.jpg	1	2026-10-11 15:43:02.119508
188	83	images/rentals/rental_12.jpg	0	2026-10-11 15:43:02.119508
189	84	images/rentals/rental_22.jpg	1	2026-10-11 15:43:02.119508
190	84	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
191	84	images/rentals/rental_16.jpg	0	2026-10-11 15:43:02.119508
192	85	images/rentals/rental_06.jpg	1	2026-10-11 15:43:02.119508
193	85	images/rentals/rental_23.jpg	0	2026-10-11 15:43:02.119508
194	86	images/rentals/rental_03.jpg	1	2026-10-11 15:43:02.119508
195	86	images/rentals/rental_29.jpg	0	2026-10-11 15:43:02.119508
196	87	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
197	87	images/rentals/rental_15.jpg	0	2026-10-11 15:43:02.119508
198	87	images/rentals/rental_22.jpg	0	2026-10-11 15:43:02.119508
199	88	images/rentals/rental_10.jpg	1	2026-10-11 15:43:02.119508
200	88	images/rentals/rental_11.jpg	0	2026-10-11 15:43:02.119508
201	89	images/rentals/rental_25.jpg	1	2026-10-11 15:43:02.119508
202	89	images/rentals/rental_21.jpg	0	2026-10-11 15:43:02.119508
203	90	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
204	90	images/rentals/rental_18.jpg	0	2026-10-11 15:43:02.119508
205	90	images/rentals/rental_19.jpg	0	2026-10-11 15:43:02.119508
206	91	images/rentals/rental_07.jpg	1	2026-10-11 15:43:02.119508
207	91	images/rentals/rental_05.jpg	0	2026-10-11 15:43:02.119508
208	92	images/rentals/rental_20.jpg	1	2026-10-11 15:43:02.119508
209	92	images/rentals/rental_17.jpg	0	2026-10-11 15:43:02.119508
210	93	images/rentals/rental_16.jpg	1	2026-10-11 15:43:02.119508
211	93	images/rentals/rental_26.jpg	0	2026-10-11 15:43:02.119508
212	93	images/rentals/rental_13.jpg	0	2026-10-11 15:43:02.119508
213	94	images/rentals/rental_29.jpg	1	2026-10-11 15:43:02.119508
214	94	images/rentals/rental_14.jpg	0	2026-10-11 15:43:02.119508
215	95	images/rentals/rental_21.jpg	1	2026-10-11 15:43:02.119508
216	95	images/rentals/rental_04.jpg	0	2026-10-11 15:43:02.119508
217	96	images/rentals/rental_20.jpg	1	2026-10-11 15:43:02.119508
218	96	images/rentals/rental_27.jpg	0	2026-10-11 15:43:02.119508
219	96	images/rentals/rental_17.jpg	0	2026-10-11 15:43:02.119508
220	97	images/rentals/rental_24.jpg	1	2026-10-11 15:43:02.119508
221	97	images/rentals/rental_28.jpg	0	2026-10-11 15:43:02.119508
222	98	images/rentals/rental_02.jpg	1	2026-10-11 15:43:02.119508
223	98	images/rentals/rental_08.jpg	0	2026-10-11 15:43:02.119508
224	99	images/rentals/rental_15.jpg	1	2026-10-11 15:43:02.119508
225	99	images/rentals/rental_30.jpg	0	2026-10-11 15:43:02.119508
226	99	images/rentals/rental_16.jpg	0	2026-10-11 15:43:02.119508
227	100	images/rentals/rental_08.jpg	1	2026-10-11 15:43:02.119508
228	100	images/rentals/rental_01.jpg	0	2026-10-11 15:43:02.119508
229	101	images/rentals/rental_12.jpg	1	2026-10-11 15:43:02.119508
230	101	images/rentals/rental_09.jpg	0	2026-10-11 15:43:02.119508
1	1	images/rentals/rental_01.jpg	1	2026-10-11 12:56:50.41717
3	2	images/rentals/rental_02.jpg	1	2026-10-11 12:56:50.41717
4	3	images/rentals/rental_03.jpg	1	2026-10-11 12:56:50.41717
\.


--
-- TOC entry 5590 (class 0 OID 27410)
-- Dependencies: 248
-- Data for Name: property_reports; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.property_reports (report_id, property_id, reporter_id, review_id, reason, description, status, assigned_admin_id, resolution_note, created_at, resolved_at) FROM stdin;
\.


--
-- TOC entry 5582 (class 0 OID 19788)
-- Dependencies: 239
-- Data for Name: property_viewings; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.property_viewings (viewing_id, customer_id, property_id, owner_id, start_time, end_time, status, customer_name, customer_phone, note, cancellation_reason, created_at, updated_at) FROM stdin;
1	2	2	5	2026-10-12 09:00:00	2026-10-12 09:30:00	Đã xác nhận	\N	\N	Lich xem da xac nhan	\N	2026-10-11 12:56:50.41717	2026-10-14 14:45:11.998959
2	3	2	5	2026-10-12 10:00:00	2026-10-12 10:30:00	Chờ xác nhận	\N	\N	Lich xem cho xac nhan	\N	2026-10-11 12:56:50.41717	2026-10-14 14:45:11.998959
3	4	2	5	2026-10-09 12:56:50.41717	2026-10-09 13:26:50.41717	Đã hoàn thành	\N	\N	Da xem bat dong san	\N	2026-10-11 12:56:50.41717	2026-10-14 14:45:11.998959
4	4	3	6	2026-10-13 14:00:00	2026-10-13 14:30:00	Đã hủy	\N	\N	\N	Bat dong san da duoc khach khac dat coc	2026-10-11 12:56:50.41717	2026-10-14 14:45:11.998959
\.


--
-- TOC entry 5592 (class 0 OID 27451)
-- Dependencies: 250
-- Data for Name: report_actions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.report_actions (action_id, report_id, admin_id, action_type, note, created_at) FROM stdin;
\.


--
-- TOC entry 5586 (class 0 OID 27352)
-- Dependencies: 244
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reviews (review_id, customer_id, property_id, rating, comment, status, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 5568 (class 0 OID 19588)
-- Dependencies: 225
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (user_id, username, email, password_hash, role, created_at, is_active, full_name, phone, cccd, updated_at, last_login_at, blocked_reason, blocked_at, blocked_by) FROM stdin;
1	0900000001	admin@gmail.com	admin_hash	ADMIN	2026-10-11 12:56:50.41717	1	Trương Văn Ngọc	0900000001	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
2	0900000002	customer01@gmail.com	customer_hash_01	CUSTOMER	2026-10-11 12:56:50.41717	1	Trần Thị Lan	0900000002	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
3	0900000003	customer02@gmail.com	customer_hash_02	CUSTOMER	2026-10-11 12:56:50.41717	1	Lê Hoàng Nam	0900000003	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
4	0900000004	customer03@gmail.com	customer_hash_03	CUSTOMER	2026-10-11 12:56:50.41717	1	Phạm Ngọc Anh	0900000004	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
5	0900000005	owner01@gmail.com	owner_hash_01	OWNER	2026-10-11 12:56:50.41717	1	Nguyễn Văn Hùng	0900000005	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
6	0900000006	owner02@gmail.com	owner_hash_02	OWNER	2026-10-11 12:56:50.41717	1	Trần Minh Đức	0900000006	\N	2026-10-13 15:37:57.078608	\N	\N	\N	\N
\.


--
-- TOC entry 5601 (class 0 OID 0)
-- Dependencies: 251
-- Name: admin_activity_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.admin_activity_logs_log_id_seq', 1, false);


--
-- TOC entry 5602 (class 0 OID 0)
-- Dependencies: 230
-- Name: apartments_apartment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.apartments_apartment_id_seq', 101, true);


--
-- TOC entry 5603 (class 0 OID 0)
-- Dependencies: 228
-- Name: buildings_building_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.buildings_building_id_seq', 26, true);


--
-- TOC entry 5604 (class 0 OID 0)
-- Dependencies: 241
-- Name: favorites_favorite_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.favorites_favorite_id_seq', 1, false);


--
-- TOC entry 5605 (class 0 OID 0)
-- Dependencies: 234
-- Name: listings_listing_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.listings_listing_id_seq', 101, true);


--
-- TOC entry 5606 (class 0 OID 0)
-- Dependencies: 245
-- Name: notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notifications_notification_id_seq', 1, false);


--
-- TOC entry 5607 (class 0 OID 0)
-- Dependencies: 232
-- Name: properties_property_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.properties_property_id_seq', 101, true);


--
-- TOC entry 5608 (class 0 OID 0)
-- Dependencies: 236
-- Name: property_images_image_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.property_images_image_id_seq', 230, true);


--
-- TOC entry 5609 (class 0 OID 0)
-- Dependencies: 247
-- Name: property_reports_report_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.property_reports_report_id_seq', 1, false);


--
-- TOC entry 5610 (class 0 OID 0)
-- Dependencies: 238
-- Name: property_viewings_viewing_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.property_viewings_viewing_id_seq', 4, true);


--
-- TOC entry 5611 (class 0 OID 0)
-- Dependencies: 249
-- Name: report_actions_action_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.report_actions_action_id_seq', 1, false);


--
-- TOC entry 5612 (class 0 OID 0)
-- Dependencies: 243
-- Name: reviews_review_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.reviews_review_id_seq', 1, false);


--
-- TOC entry 5613 (class 0 OID 0)
-- Dependencies: 224
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_user_id_seq', 6, true);


--
-- TOC entry 5377 (class 2606 OID 27488)
-- Name: admin_activity_logs admin_activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_activity_logs
    ADD CONSTRAINT admin_activity_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 5331 (class 2606 OID 19682)
-- Name: apartments apartments_building_id_apartment_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_building_id_apartment_code_key UNIQUE (building_id, apartment_code);


--
-- TOC entry 5333 (class 2606 OID 19680)
-- Name: apartments apartments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_pkey PRIMARY KEY (apartment_id);


--
-- TOC entry 5327 (class 2606 OID 19652)
-- Name: buildings buildings_building_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT buildings_building_code_key UNIQUE (building_code);


--
-- TOC entry 5329 (class 2606 OID 19650)
-- Name: buildings buildings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT buildings_pkey PRIMARY KEY (building_id);


--
-- TOC entry 5325 (class 2606 OID 19624)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- TOC entry 5357 (class 2606 OID 27337)
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (favorite_id);


--
-- TOC entry 5342 (class 2606 OID 19752)
-- Name: listings listings_listing_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_listing_code_key UNIQUE (listing_code);


--
-- TOC entry 5344 (class 2606 OID 19750)
-- Name: listings listings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_pkey PRIMARY KEY (listing_id);


--
-- TOC entry 5346 (class 2606 OID 19754)
-- Name: listings listings_property_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_property_id_key UNIQUE (property_id);


--
-- TOC entry 5353 (class 2606 OID 27303)
-- Name: property_viewings no_overlapping_viewings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_viewings
    ADD CONSTRAINT no_overlapping_viewings EXCLUDE USING gist (property_id WITH =, tsrange(start_time, end_time, '[)'::text) WITH &&) WHERE (((status)::text = ANY ((ARRAY['Chờ xác nhận'::character varying, 'Đã xác nhận'::character varying, 'Đã hoàn thành'::character varying])::text[])));


--
-- TOC entry 5368 (class 2606 OID 27402)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_id);


--
-- TOC entry 5323 (class 2606 OID 19613)
-- Name: owners owners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owners
    ADD CONSTRAINT owners_pkey PRIMARY KEY (owner_id);


--
-- TOC entry 5337 (class 2606 OID 19720)
-- Name: properties properties_apartment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_apartment_id_key UNIQUE (apartment_id);


--
-- TOC entry 5339 (class 2606 OID 19718)
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (property_id);


--
-- TOC entry 5348 (class 2606 OID 19780)
-- Name: property_images property_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_images
    ADD CONSTRAINT property_images_pkey PRIMARY KEY (image_id);


--
-- TOC entry 5372 (class 2606 OID 27427)
-- Name: property_reports property_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_reports
    ADD CONSTRAINT property_reports_pkey PRIMARY KEY (report_id);


--
-- TOC entry 5355 (class 2606 OID 19808)
-- Name: property_viewings property_viewings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_viewings
    ADD CONSTRAINT property_viewings_pkey PRIMARY KEY (viewing_id);


--
-- TOC entry 5375 (class 2606 OID 27464)
-- Name: report_actions report_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_actions
    ADD CONSTRAINT report_actions_pkey PRIMARY KEY (action_id);


--
-- TOC entry 5363 (class 2606 OID 27370)
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (review_id);


--
-- TOC entry 5360 (class 2606 OID 27339)
-- Name: favorites uq_favorites_user_property; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT uq_favorites_user_property UNIQUE (user_id, property_id);


--
-- TOC entry 5365 (class 2606 OID 27372)
-- Name: reviews uq_reviews_customer_property; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT uq_reviews_customer_property UNIQUE (customer_id, property_id);


--
-- TOC entry 5315 (class 2606 OID 19607)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 5317 (class 2606 OID 19603)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 5319 (class 2606 OID 19605)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 5378 (class 1259 OID 27494)
-- Name: idx_admin_logs_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_logs_time ON public.admin_activity_logs USING btree (created_at DESC);


--
-- TOC entry 5334 (class 1259 OID 19827)
-- Name: idx_apartments_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_apartments_owner ON public.apartments USING btree (owner_id);


--
-- TOC entry 5358 (class 1259 OID 27350)
-- Name: idx_favorites_property; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorites_property ON public.favorites USING btree (property_id);


--
-- TOC entry 5340 (class 1259 OID 27326)
-- Name: idx_listings_moderation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_listings_moderation ON public.listings USING btree (moderation_status, post_date DESC);


--
-- TOC entry 5366 (class 1259 OID 27408)
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, is_read, created_at DESC);


--
-- TOC entry 5335 (class 1259 OID 19826)
-- Name: idx_properties_type_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_properties_type_status ON public.properties USING btree (listing_type, status);


--
-- TOC entry 5369 (class 1259 OID 27449)
-- Name: idx_property_reports_property; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_property_reports_property ON public.property_reports USING btree (property_id);


--
-- TOC entry 5370 (class 1259 OID 27448)
-- Name: idx_property_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_property_reports_status ON public.property_reports USING btree (status, created_at DESC);


--
-- TOC entry 5373 (class 1259 OID 27475)
-- Name: idx_report_actions_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_actions_report ON public.report_actions USING btree (report_id, created_at DESC);


--
-- TOC entry 5361 (class 1259 OID 27383)
-- Name: idx_reviews_property; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_property ON public.reviews USING btree (property_id, status);


--
-- TOC entry 5350 (class 1259 OID 19825)
-- Name: idx_viewings_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_viewings_customer ON public.property_viewings USING btree (customer_id);


--
-- TOC entry 5351 (class 1259 OID 19824)
-- Name: idx_viewings_owner_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_viewings_owner_time ON public.property_viewings USING btree (owner_id, start_time);


--
-- TOC entry 5311 (class 1259 OID 19858)
-- Name: uq_users_cccd; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_users_cccd ON public.users USING btree (cccd) WHERE (cccd IS NOT NULL);


--
-- TOC entry 5312 (class 1259 OID 19859)
-- Name: uq_users_email_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_users_email_normalized ON public.users USING btree (lower(TRIM(BOTH FROM email)));


--
-- TOC entry 5313 (class 1259 OID 26573)
-- Name: uq_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_users_phone ON public.users USING btree (phone);


--
-- TOC entry 5349 (class 1259 OID 19786)
-- Name: ux_property_thumbnail; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_property_thumbnail ON public.property_images USING btree (property_id) WHERE (is_thumbnail = 1);


--
-- TOC entry 5320 (class 1259 OID 27316)
-- Name: ux_users_cccd_nonnull; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_users_cccd_nonnull ON public.users USING btree (cccd) WHERE (cccd IS NOT NULL);


--
-- TOC entry 5321 (class 1259 OID 27315)
-- Name: ux_users_phone_nonnull; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_users_phone_nonnull ON public.users USING btree (phone) WHERE (phone IS NOT NULL);


--
-- TOC entry 5409 (class 2620 OID 27504)
-- Name: property_viewings trg_00_assign_viewing_owner; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_00_assign_viewing_owner BEFORE INSERT OR UPDATE OF property_id ON public.property_viewings FOR EACH ROW EXECUTE FUNCTION public.assign_viewing_owner();


--
-- TOC entry 5407 (class 2620 OID 27499)
-- Name: listings trg_check_admin_listings; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_admin_listings BEFORE INSERT OR UPDATE OF reviewed_by ON public.listings FOR EACH ROW EXECUTE FUNCTION public.check_admin_actor();


--
-- TOC entry 5415 (class 2620 OID 27497)
-- Name: admin_activity_logs trg_check_admin_logs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_admin_logs BEFORE INSERT OR UPDATE OF admin_id ON public.admin_activity_logs FOR EACH ROW EXECUTE FUNCTION public.check_admin_actor();


--
-- TOC entry 5414 (class 2620 OID 27496)
-- Name: report_actions trg_check_admin_report_actions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_admin_report_actions BEFORE INSERT OR UPDATE OF admin_id ON public.report_actions FOR EACH ROW EXECUTE FUNCTION public.check_admin_actor();


--
-- TOC entry 5413 (class 2620 OID 27498)
-- Name: property_reports trg_check_admin_reports; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_admin_reports BEFORE INSERT OR UPDATE OF assigned_admin_id ON public.property_reports FOR EACH ROW EXECUTE FUNCTION public.check_admin_actor();


--
-- TOC entry 5412 (class 2620 OID 27501)
-- Name: reviews trg_check_review_customer; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_review_customer BEFORE INSERT OR UPDATE OF customer_id ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.check_customer_action();


--
-- TOC entry 5410 (class 2620 OID 27502)
-- Name: property_viewings trg_check_viewing_customer; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_viewing_customer BEFORE INSERT OR UPDATE OF customer_id ON public.property_viewings FOR EACH ROW EXECUTE FUNCTION public.check_customer_action();


--
-- TOC entry 5408 (class 2620 OID 19831)
-- Name: listings trg_listing_owner; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_listing_owner BEFORE INSERT OR UPDATE OF owner_id, property_id, listing_type ON public.listings FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_owner();


--
-- TOC entry 5404 (class 2620 OID 19833)
-- Name: apartments trg_owner_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_owner_change BEFORE UPDATE OF owner_id ON public.apartments FOR EACH ROW EXECUTE FUNCTION public.prevent_owner_change_with_links();


--
-- TOC entry 5405 (class 2620 OID 19843)
-- Name: apartments trg_propagate_apartment_area; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_propagate_apartment_area AFTER UPDATE OF area ON public.apartments FOR EACH ROW WHEN ((old.area IS DISTINCT FROM new.area)) EXECUTE FUNCTION public.propagate_apartment_area();


--
-- TOC entry 5406 (class 2620 OID 19841)
-- Name: properties trg_sync_property_area; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_property_area BEFORE INSERT OR UPDATE OF apartment_id, area ON public.properties FOR EACH ROW EXECUTE FUNCTION public.sync_property_area();


--
-- TOC entry 5411 (class 2620 OID 19829)
-- Name: property_viewings trg_viewing_owner; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_viewing_owner BEFORE INSERT OR UPDATE OF owner_id, property_id ON public.property_viewings FOR EACH ROW EXECUTE FUNCTION public.enforce_owner_consistency();


--
-- TOC entry 5403 (class 2606 OID 27489)
-- Name: admin_activity_logs admin_activity_logs_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_activity_logs
    ADD CONSTRAINT admin_activity_logs_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(user_id);


--
-- TOC entry 5382 (class 2606 OID 19683)
-- Name: apartments apartments_building_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_building_id_fkey FOREIGN KEY (building_id) REFERENCES public.buildings(building_id);


--
-- TOC entry 5383 (class 2606 OID 19688)
-- Name: apartments apartments_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apartments
    ADD CONSTRAINT apartments_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.owners(owner_id);


--
-- TOC entry 5381 (class 2606 OID 19625)
-- Name: customers customers_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 5392 (class 2606 OID 27345)
-- Name: favorites favorites_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id) ON DELETE CASCADE;


--
-- TOC entry 5393 (class 2606 OID 27340)
-- Name: favorites favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 5379 (class 2606 OID 27310)
-- Name: users fk_users_blocked_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_blocked_by FOREIGN KEY (blocked_by) REFERENCES public.users(user_id) NOT VALID;


--
-- TOC entry 5385 (class 2606 OID 19755)
-- Name: listings listings_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.owners(owner_id);


--
-- TOC entry 5386 (class 2606 OID 19760)
-- Name: listings listings_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 5387 (class 2606 OID 27319)
-- Name: listings listings_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listings
    ADD CONSTRAINT listings_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(user_id);


--
-- TOC entry 5396 (class 2606 OID 27403)
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- TOC entry 5380 (class 2606 OID 19614)
-- Name: owners owners_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owners
    ADD CONSTRAINT owners_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(user_id) ON DELETE RESTRICT;


--
-- TOC entry 5384 (class 2606 OID 19721)
-- Name: properties properties_apartment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_apartment_id_fkey FOREIGN KEY (apartment_id) REFERENCES public.apartments(apartment_id);


--
-- TOC entry 5388 (class 2606 OID 19781)
-- Name: property_images property_images_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_images
    ADD CONSTRAINT property_images_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id) ON DELETE CASCADE;


--
-- TOC entry 5397 (class 2606 OID 27443)
-- Name: property_reports property_reports_assigned_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_reports
    ADD CONSTRAINT property_reports_assigned_admin_id_fkey FOREIGN KEY (assigned_admin_id) REFERENCES public.users(user_id);


--
-- TOC entry 5398 (class 2606 OID 27428)
-- Name: property_reports property_reports_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_reports
    ADD CONSTRAINT property_reports_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 5399 (class 2606 OID 27433)
-- Name: property_reports property_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_reports
    ADD CONSTRAINT property_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(user_id);


--
-- TOC entry 5400 (class 2606 OID 27438)
-- Name: property_reports property_reports_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_reports
    ADD CONSTRAINT property_reports_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(review_id);


--
-- TOC entry 5389 (class 2606 OID 19809)
-- Name: property_viewings property_viewings_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_viewings
    ADD CONSTRAINT property_viewings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id);


--
-- TOC entry 5390 (class 2606 OID 19819)
-- Name: property_viewings property_viewings_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_viewings
    ADD CONSTRAINT property_viewings_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.owners(owner_id);


--
-- TOC entry 5391 (class 2606 OID 19814)
-- Name: property_viewings property_viewings_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.property_viewings
    ADD CONSTRAINT property_viewings_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


--
-- TOC entry 5401 (class 2606 OID 27470)
-- Name: report_actions report_actions_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_actions
    ADD CONSTRAINT report_actions_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(user_id);


--
-- TOC entry 5402 (class 2606 OID 27465)
-- Name: report_actions report_actions_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_actions
    ADD CONSTRAINT report_actions_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.property_reports(report_id);


--
-- TOC entry 5394 (class 2606 OID 27373)
-- Name: reviews reviews_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id);


--
-- TOC entry 5395 (class 2606 OID 27378)
-- Name: reviews reviews_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(property_id);


-- Completed on 2026-10-14 15:29:58

--
-- PostgreSQL database dump complete
--

\unrestrict 4FtjGtIDuzKzhiBxuGcCYgzco7Ef1WVgEeHX0JCrZXaYpWcoByQa2XTbjukuopJ

