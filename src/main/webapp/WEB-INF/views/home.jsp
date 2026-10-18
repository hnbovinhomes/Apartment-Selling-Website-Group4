<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Apartment Website</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/home.css?v=6">
</head>
<body id="top">
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<section class="hero">
    <div class="hero-overlay"></div>
    <div class="hero-content">
        <span class="hero-badge">
            APARTMENT SELLING WEBSITE
        </span>
        <h1>
            Tìm nơi ở phù hợp với cuộc sống của bạn
        </h1>
        <p>
            Tìm kiếm, so sánh và giao dịch bất động sản minh bạch hơn
        </p>
        <!-- SEARCH -->
        <form class="search-box"
              action="${ctx}/properties"
              method="get">
            <div class="search-icon">
                🔍
            </div>
            <input
                    type="text"
                    name="keyword"
                    placeholder="Tìm theo khu vực, giá, diện tích..."
            >
            <button type="submit">
                Tìm kiếm
            </button>
        </form>
        <div class="quick-search">
            <span>Tìm nhanh:</span>
            <a href="${ctx}/properties?location=Thu%20Duc">
                Thủ Đức
            </a>
            <a href="${ctx}/properties?location=Di%20An">
                Dĩ An
            </a>
            <a href="${ctx}/properties?bedrooms=2">
                2 phòng ngủ
            </a>
            <a href="${ctx}/properties?price=under2">
                Dưới 2 tỷ
            </a>
        </div>
    </div>

</section>

<main>
  <section class="quick-section">
    <div class="container">
      <div class="section-heading center"><span class="section-label">KHÁM PHÁ</span><h2>Mọi thứ bạn cần cho một giao dịch</h2>
        <p>Từ tìm kiếm căn hộ đến đặt lịch xem và quản lý giao dịch.</p></div>
      <div class="service-grid">
        <div class="service-card"><div class="service-icon">🏠</div><h3>Tìm căn hộ</h3><p>Tìm kiếm và lọc căn hộ theo nhu cầu.</p><a href="${ctx}/properties" class="service-link">Khám phá →</a></div>
        <div class="service-card"><div class="service-icon">📝</div><h3>Đăng tin</h3><p>Đăng tin bất động sản nhanh chóng.</p><a href="${ctx}${currentUser.owner ? '/postings?action=create' : '/auth?action=register&role=OWNER'}" class="service-link">Khám phá →</a></div>
        <div class="service-card"><div class="service-icon">⚖️</div><h3>So sánh</h3><p>So sánh nhiều căn hộ trước khi quyết định.</p><a href="${ctx}/comparisons" class="service-link">Khám phá →</a></div>
        <div class="service-card"><div class="service-icon">📅</div><h3>Đặt lịch xem</h3><p>Chủ động chọn thời gian xem căn hộ.</p><a href="${ctx}/properties" class="service-link">Khám phá →</a></div>
      </div>
    </div>
  </section>

  <section class="property-section">
    <div class="container">
      <div class="section-heading">
        <div><span class="section-label">NỔI BẬT</span><h2>Căn hộ dành cho bạn</h2><p>Một số bất động sản đang được quan tâm.</p></div>
        <a href="${ctx}/properties" class="view-all">Xem tất cả →</a>
      </div>
      <div class="property-grid">
        <!-- "featured" do HomeController gửi sang -->
        <c:forEach var="it" items="${featured}">
        <article class="property-card">
          <div class="property-image"><img src="<c:url value='${it.thumbnailUrl}'/>" alt="<c:out value="${it.title}"/>"><span class="property-status"><c:out value="${it.status}"/></span></div>
          <div class="property-content">
            <div class="property-price"><c:out value="${it.priceText}"/></div>
            <h3><c:out value="${it.title}"/></h3>
            <p class="property-location">📍 <c:out value="${it.address}"/>, <c:out value="${it.district}"/>, <c:out value="${it.city}"/></p>
            <div class="property-meta"><span>📐 <b><c:out value="${it.area}"/></b> m²</span><span>🛏 <b><c:out value="${it.bedrooms}"/></b> PN</span><span>🚿 <b><c:out value="${it.bathrooms}"/></b> WC</span></div>
            <a href="${ctx}/properties?action=detail&id=<c:out value="${it.propertyId}"/>" class="property-button">Xem chi tiết</a>
          </div>
        </article>
        </c:forEach>
      </div>
    </div>
  </section>

  <!-- TRUST / SYSTEM -->
    <section class="trust-section">
        <div class="container trust-wrapper">
            <div class="trust-text">
                <span class="section-label">
                    AN TÂM GIAO DỊCH
                </span>
                <h2>
                    Tìm kiếm thông tin rõ ràng,
                    giao dịch minh bạch
                </h2>
                <p>
                    Apartment Website hỗ trợ người mua và chủ sở hữu
                    trong suốt quá trình tìm kiếm, xem căn hộ và thực hiện
                    giao dịch.
                </p>
                <div class="trust-list">
                    <div class="trust-item">
                        <span>✓</span>
                        <div>
                            <strong>Thông tin rõ ràng</strong>
                            <p>
                                Thông tin bất động sản được trình bày tập trung.
                            </p>
                        </div>
                    </div>

                    <div class="trust-item">
                        <span>✓</span>
                        <div>
                            <strong>Đặt lịch xem</strong>
                            <p>
                                Chủ động lựa chọn thời gian xem căn hộ.
                            </p>
                        </div>
                    </div>

                    <div class="trust-item">
                        <span>✓</span>
                        <div>
                            <strong>Quản lý giao dịch</strong>
                            <p>
                                Theo dõi trạng thái giao dịch trên hệ thống.
                            </p>
                        </div>
                    </div>
                </div>
            </div>


            <div class="trust-card">
                <div class="trust-card-icon">
                    ✓
                </div>
                <h3>
                    Apartment Website
                </h3>
                <p>
                    Nền tảng kết nối người mua và chủ sở hữu
                    trong quy trình giao dịch bất động sản.
                </p>
                <div class="trust-stat">
                    <div>
                        <strong>24/7</strong>
                        <span>Truy cập</span>
                    </div>
                    <div>
                        <strong>100%</strong>
                        <span>Trực tuyến</span>
                    </div>
                </div>
            </div>
        </div>
    </section>


    
  <section class="notification-section">
    <div class="container"><div class="notification-panel">
      <div class="notification-header"><div><span class="section-label">CẬP NHẬT</span><h2>Thông báo mới</h2></div><button>Xem tất cả</button></div>
      <div class="notification-list">
          <div class="notification-item"><div class="notification-icon">🔔</div><div><h4>Lịch xem được xác nhận</h4><p>Chủ nhà đã xác nhận lịch xem căn hộ.</p></div><span class="notification-arrow">→</span></div>
          <div class="notification-item"><div class="notification-icon">🔔</div><div><h4>Giá căn hộ thay đổi</h4><p>Một căn hộ trong danh sách so sánh vừa đổi giá.</p></div><span class="notification-arrow">→</span></div>
          <div class="notification-item"><div class="notification-icon">🔔</div><div><h4>Tin đăng đã duyệt</h4><p>Tin đăng của bạn đã được hiển thị.</p></div><span class="notification-arrow">→</span></div>
      </div>
    </div></div>
  </section>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
