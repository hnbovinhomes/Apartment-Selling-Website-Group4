<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  Trang "Quản lý tin" của ADMIN: rà soát tất cả căn hộ đã đăng, xóa căn sai mô tả.
  ListingServlet gửi sang: listings (List<Listing>, có ownerName/ownerPhone từ JOIN users), q (từ khóa), message, error
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Rà soát tin đăng</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/account.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <div class="acc-head">
    <div>
      <h1 class="page__title">Rà soát tin đăng</h1>
      <p class="acc-sub">Có <b>${listings.size()}</b> tin đã đăng${empty q ? '' : ' khớp từ khóa'}. Mở xem chi tiết, căn nào sai mô tả thì xóa và ghi lý do để báo cho chủ căn hộ.</p>
    </div>
    <%-- GET /postings?q=... : tìm theo tiêu đề, mã tin, tên hoặc SĐT chủ căn hộ --%>
    <form class="admin-search" method="get" action="${ctx}/postings">
      <label class="sr-only" for="q">Tìm tin đăng</label>
      <input class="input" id="q" name="q" placeholder="Tiêu đề, mã tin, tên / SĐT chủ..." value="<c:out value="${q}"/>">
      <button class="btn btn--primary" type="submit">Tìm</button>
      <c:if test="${not empty q}"><a class="btn btn--outline" href="${ctx}/postings">Xóa lọc</a></c:if>
    </form>
  </div>

  <c:if test="${not empty message}"><p class="alert alert--ok" role="status">✓ <c:out value="${message}"/></p></c:if>
  <c:if test="${not empty error}"><p class="alert alert--err" role="alert">⚠ <c:out value="${error}"/></p></c:if>

  <c:choose>
    <c:when test="${empty listings}">
      <div class="empty-box"><p>Không có tin đăng nào.</p></div>
    </c:when>
    <c:otherwise>
      <div class="tbl-wrap">
        <table class="tbl tbl--admin">
          <thead><tr><th>Mã tin</th><th>Tiêu đề</th><th>Chủ căn hộ</th><th>Loại</th><th>Giá</th><th>Ngày đăng</th><th>Trạng thái</th><th></th></tr></thead>
          <tbody>
            <c:forEach var="l" items="${listings}">
              <tr>
                <td><c:out value="${l.listingCode}"/></td>
                <td><a href="${ctx}/properties?action=detail&id=${l.propertyId}" target="_blank" rel="noopener"><c:out value="${l.listingTitle}"/></a></td>
                <td><c:out value="${l.ownerName}"/><br><small class="acc-sub"><c:out value="${l.ownerPhone}"/></small></td>
                <td><span class="badge ${l.rent ? 'badge--rent' : ''}">${l.rent ? 'Thuê' : 'Bán'}</span></td>
                <td><c:out value="${l.priceText}"/></td>
                <td><c:out value="${l.postDateText}"/></td>
                <td><c:out value="${l.statusText}"/></td>
                <td>
                  <%-- Xóa: mở ô nhập lý do bằng <details>, POST action=delete --%>
                  <details class="reason-box">
                    <summary class="btn btn--danger">Xóa</summary>
                    <form method="post" action="${ctx}/postings">
                      <input type="hidden" name="action" value="delete">
                      <input type="hidden" name="id" value="${l.listingId}">
                      <input type="hidden" name="q" value="<c:out value="${q}"/>">
                      <textarea class="input textarea" name="reason" maxlength="500" required placeholder="Lý do xóa (vd: ảnh không đúng căn hộ, sai diện tích...)"></textarea>
                      <button class="btn btn--danger-fill" type="submit">Xác nhận xóa</button>
                    </form>
                  </details>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>
      <p class="acc-sub admin-note">Xóa sẽ gỡ căn khỏi danh sách cùng ảnh, đánh giá, lịch hẹn của căn đó; chủ căn hộ và khách đang có lịch hẹn nhận thông báo ở 🔔.</p>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
