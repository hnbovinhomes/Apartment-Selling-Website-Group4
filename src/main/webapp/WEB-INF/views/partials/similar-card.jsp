<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- 1 thẻ căn hộ ở mục "Căn hộ tương tự" (detail.jsp). Trang gọi phải đặt sẵn request attribute "card" = 1 Property. --%>
<a class="similar-card" href="${ctx}/properties?action=detail&id=<c:out value="${card.propertyId}"/>">
  <img class="similar-card__img" src="<c:url value='${card.thumbnailUrl}'/>" alt="<c:out value="${card.title}"/>">
  <div class="similar-card__body">
    <div class="similar-card__top">
      <span class="badge">${card.rent ? 'Thuê' : 'Bán'}</span>
      <span class="similar-card__price"><c:out value="${card.priceText}"/></span>
    </div>
    <h3 class="similar-card__title"><c:out value="${card.title}"/></h3>
    <p class="similar-card__location">📍 <c:out value="${card.district}"/>, <c:out value="${card.city}"/></p>
    <p class="similar-card__meta"><span>🛏 <c:out value="${card.bedrooms}"/> PN</span>|<span>🛁 <c:out value="${card.bathrooms}"/> WC</span>|<span>📐 <c:out value="${card.area}"/>m²</span></p>
  </div>
</a>
