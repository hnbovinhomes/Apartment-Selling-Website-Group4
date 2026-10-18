<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- ListingServlet gửi sang: listings (List<Listing>) = các dòng của bảng listings có owner_id = chủ căn hộ đang đăng nhập --%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Quản lý tin đăng</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/account.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <div class="acc-head">
    <div>
      <h1 class="page__title">Quản lý tin đăng</h1>
      <p class="acc-sub">Bạn đã đăng <b>${listings.size()}</b> tin. Tin đăng xong là hiện ngay trên trang Danh sách căn hộ.</p>
    </div>
    <a class="btn btn--primary" href="${ctx}/postings?action=create">+ Đăng tin mới</a>
  </div>

  <c:choose>
    <c:when test="${empty listings}">
      <div class="empty-box"><p>Bạn chưa có tin đăng nào.</p>
        <a class="btn btn--primary" href="${ctx}/postings?action=create">Đăng tin đầu tiên</a></div>
    </c:when>
    <c:otherwise>
      <div class="tbl-wrap">
        <table class="tbl">
          <thead><tr><th>Mã tin</th><th>Tiêu đề</th><th>Loại</th><th>Giá</th><th>Ngày đăng</th><th>Trạng thái</th></tr></thead>
          <tbody>
            <c:forEach var="l" items="${listings}">
              <tr>
                <td><c:out value="${l.listingCode}"/></td>
                <td><a href="${ctx}/properties?action=detail&id=${l.propertyId}"><c:out value="${l.listingTitle}"/></a></td>
                <td><span class="badge ${l.rent ? 'badge--rent' : ''}">${l.rent ? 'Thuê' : 'Bán'}</span></td>
                <td><c:out value="${l.priceText}"/></td>
                <td><c:out value="${l.postDateText}"/></td>
                <td><span class="posted">✓ <c:out value="${l.statusText}"/></span></td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
