<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Danh sách căn hộ</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/listing-list.css?v=6">
</head>
<body id="top">
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <!-- THANH LỌC: gửi GET /properties?district=..&price=..&bedrooms=..&keyword=.. -->
  <div class="filter-bar__tabs" style="display:flex;gap:8px;margin-bottom:12px">
    <a class="btn ${type == 'RENT' ? 'btn--outline' : 'btn--primary'}" href="${ctx}/properties?type=SALE">Căn hộ bán</a>
    <a class="btn ${type == 'RENT' ? 'btn--primary' : 'btn--outline'}" href="${ctx}/properties?type=RENT">Căn hộ cho thuê</a>
  </div>
  <form class="filter-bar" method="get" action="${ctx}/properties">
    <input type="hidden" name="type" value="<c:out value="${type}"/>">
    <label class="filter-bar__item">Khu vực:
      <select class="input" name="district">
        <option value="">Tất cả</option>
        <%-- districts: List<String>; district: quận đang chọn --%>
        <c:forEach var="d" items="${districts}"><option value="<c:out value="${d}"/>" ${d == district ? 'selected' : ''}><c:out value="${d}"/></option></c:forEach>
      </select></label>
    <c:if test="${type != 'RENT'}">
    <label class="filter-bar__item">Mức giá:
      <select class="input" name="price">
        <option value="">Tất cả</option>
        <option value="under2" ${param.price == 'under2' ? 'selected' : ''}>Dưới 2 tỷ</option>
        <option value="2to4" ${param.price == '2to4' ? 'selected' : ''}>2 - 4 tỷ</option>
        <option value="over4" ${param.price == 'over4' ? 'selected' : ''}>Trên 4 tỷ</option>
      </select></label>
    </c:if>
    <label class="filter-bar__item">Số phòng ngủ:
      <select class="input" name="bedrooms">
        <option value="">Tất cả</option>
        <option value="1" ${param.bedrooms == '1' ? 'selected' : ''}>1 PN</option><option value="2" ${param.bedrooms == '2' ? 'selected' : ''}>2 PN</option><option value="3" ${param.bedrooms == '3' ? 'selected' : ''}>3+ PN</option>
      </select></label>
    <input class="input filter-bar__search" type="text" name="keyword" value="<c:out value="${param.keyword}"/>" placeholder="Tìm theo tên dự án, đường...">
    <button class="btn btn--primary" type="submit">Lọc ngay</button>
  </form>

  <p class="result-count">Tìm thấy <strong><c:out value="${total}"/></strong> căn hộ phù hợp<c:if test="${total > 0 and not empty to}"> <span class="result-range">(hiển thị <c:out value="${from}"/>–<c:out value="${to}"/>)</span></c:if></p>
  <c:if test="${noResult}"><p>Không có căn hộ nào phù hợp với bộ lọc.</p></c:if>

  <!-- MỖI PHẦN TỬ TRONG danh sách "properties" (Controller gửi sang) = 1 thẻ căn hộ -->
  <section class="apartment-grid">
    <c:forEach var="it" items="${properties}">
    <article class="apartment-card">
      <img class="apartment-card__img" src="<c:url value='${it.thumbnailUrl}'/>" alt="<c:out value="${it.title}"/>">
      <div class="apartment-card__body">
        <div class="apartment-card__top">
          <span class="badge">${it.rent ? 'Thuê' : 'Bán'}</span>
          <span class="apartment-card__price"><c:out value="${it.priceText}"/></span>
        </div>
        <h3 class="apartment-card__title"><c:out value="${it.title}"/></h3>
        <p class="apartment-card__location">📍 <c:out value="${it.district}"/>, <c:out value="${it.city}"/></p>
        <p class="apartment-card__meta"><span>🛏 <c:out value="${it.bedrooms}"/> PN</span>|<span>🛁 <c:out value="${it.bathrooms}"/> WC</span>|<span>📐 <c:out value="${it.area}"/>m²</span></p>
        <div class="apartment-card__actions">
          <a class="btn btn--primary" href="${ctx}/properties?action=detail&id=<c:out value="${it.propertyId}"/>">Xem chi tiết</a>
          <form method="post" action="${ctx}/comparisons" style="display:contents">
            <input type="hidden" name="action" value="add"><input type="hidden" name="id" value="<c:out value="${it.propertyId}"/>">
            <button class="btn btn--outline" type="submit" style="cursor:pointer">⊞ Thêm so sánh</button>
          </form>
        </div>
      </div>
    </article>
    </c:forEach>
  </section>

  <c:if test="${empty totalPages or totalPages > 1}">
  <nav class="pagination" aria-label="Phân trang">
    <%-- pages: List<PageLink> (JavaBean) do PropertyService.pageLinks() tạo --%>
    <c:forEach var="it" items="${pages}">
      <c:choose>
        <%-- href = null: « ở trang đầu, » ở trang cuối, dấu … -> không bấm được --%>
        <c:when test="${empty it.href}"><span class="pagination__item is-disabled"><c:out value="${it.label}"/></span></c:when>
        <%-- it.active là true/false (Boolean) nên phải dùng toán tử ?: chứ không in thẳng ra class --%>
        <c:otherwise><a class="pagination__item${it.active ? ' is-active' : ''}" href="<c:out value="${it.href}"/>"><c:out value="${it.label}"/></a></c:otherwise>
      </c:choose>
    </c:forEach>
  </nav>
  </c:if>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
