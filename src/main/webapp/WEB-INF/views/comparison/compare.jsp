<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>So sánh căn hộ</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/compare.css?v=6">
</head>
<body id="top">
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <h1 class="cmpx-title">Bảng So sánh Căn hộ - Tìm Căn Hộ Phù Hợp Nhất</h1>

  <c:if test="${full}"><p class="cmpx-note">Chỉ so sánh được tối đa <c:out value="${maxItems}"/> căn. Hãy bỏ bớt một căn trước khi thêm căn mới.</p></c:if>

  <c:choose>
  <c:when test="${empty items}">
    <div class="cmpx-none">
      <p>Bạn chưa chọn căn hộ nào để so sánh.</p>
      <p>Vào danh sách căn hộ, bấm <strong> ⊞ Thêm so sánh</strong> ở các căn bạn quan tâm (tối đa <c:out value="${maxItems}"/> căn).</p>
      <a class="btn btn--primary" href="${ctx}/properties">Xem danh sách căn hộ</a>
    </div>
  </c:when>
  <c:otherwise>
  <div class="cmpx-wrap">
    <table class="cmpx-table">
      <tr>
        <th class="cmpx-label"></th>
        <c:forEach var="it" items="${items}">
          <th>
            <div class="cmpx-head">
              <img src="<c:url value='${it.thumbnailUrl}'/>" alt="<c:out value="${it.title}"/>">
              <div>
                <a href="${ctx}/properties?action=detail&id=<c:out value="${it.propertyId}"/>"><c:out value="${it.title}"/></a>
                <small><c:out value="${it.rent ? 'Cho thuê' : 'Bán'}"/> · <c:out value="${it.buildingName}"/></small>
              </div>
              <form method="post" action="${ctx}/comparisons" style="margin:0">
                <input type="hidden" name="action" value="remove">
                <input type="hidden" name="id" value="<c:out value="${it.propertyId}"/>">
                <button class="cmpx-remove" type="submit" title="Bỏ khỏi so sánh">×</button>
              </form>
            </div>
          </th>
        </c:forEach>
        <c:forEach var="n" items="${emptySlots}"><th class="cmpx-empty">Căn hộ <c:out value="${n}"/> (trống)</th></c:forEach>
      </tr>

      <tr><th class="cmpx-label">Giá</th>
        <c:forEach var="it" items="${items}"><td class="cmpx-price"><c:out value="${it.priceText}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Giá / m²</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${empty it.pricePerM2Text ? '—' : it.pricePerM2Text}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Diện tích (m²)</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${it.area}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Phòng ngủ (PN)</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${it.bedrooms}"/> PN</td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Nhà vệ sinh (WC)</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${it.bathrooms}"/> WC</td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Tầng</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${it.floor}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Hướng</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${empty it.direction ? '—' : it.direction}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Pháp lý</th>
        <c:forEach var="it" items="${items}"><td>
          <c:choose>
            <c:when test="${it.legalStatus == 'CERTIFIED'}">Đã có sổ</c:when>
            <c:when test="${it.legalStatus == 'PENDING'}">Đang chờ sổ</c:when>
            <c:when test="${it.legalStatus == 'MORTGAGED'}">Đang thế chấp</c:when>
            <c:when test="${it.legalStatus == 'DISPUTED'}">Đang tranh chấp</c:when>
            <c:otherwise><c:out value="${empty it.legalStatus ? '—' : it.legalStatus}"/></c:otherwise>
          </c:choose></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label">Khu vực</th>
        <c:forEach var="it" items="${items}"><td><c:out value="${it.district}"/>, <c:out value="${it.city}"/></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td class="cmpx-empty">—</td></c:forEach></tr>

      <tr><th class="cmpx-label"></th>
        <c:forEach var="it" items="${items}"><td><div class="cmpx-actions">
          <a class="btn btn--primary" href="${ctx}/appointments?propertyId=<c:out value="${it.propertyId}"/>">Đặt lịch xem</a>
          <a class="btn btn--outline" href="${ctx}/properties?action=detail&id=<c:out value="${it.propertyId}"/>">Xem chi tiết</a>
        </div></td></c:forEach>
        <c:forEach var="n" items="${emptySlots}"><td></td></c:forEach></tr>
    </table>
  </div>

  <c:if test="${canAdd}"><a class="btn btn--outline cmpx-add" href="${ctx}/properties">+ Thêm căn hộ so sánh</a></c:if>
  <form class="cmpx-clear" method="post" action="${ctx}/comparisons">
    <input type="hidden" name="action" value="clear"><button type="submit">Xóa tất cả</button>
  </form>
  </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
