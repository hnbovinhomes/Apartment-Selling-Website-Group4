<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- NotificationServlet gửi sang: notifications (List<Notification>). unreadCount do AuthFilter đặt. --%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Thông báo</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/account.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <div class="acc-head">
    <div>
      <h1 class="page__title">Thông báo</h1>
      <p class="acc-sub">Bạn có <b><c:out value="${unreadCount}"/></b> thông báo chưa đọc.</p>
    </div>
    <c:if test="${unreadCount > 0}">
      <form method="post" action="${ctx}/notifications">
        <input type="hidden" name="action" value="readAll">
        <button class="btn btn--outline" type="submit">Đánh dấu đã đọc tất cả</button>
      </form>
    </c:if>
  </div>

  <c:choose>
    <c:when test="${empty notifications}">
      <div class="empty-box"><p>Chưa có thông báo nào.</p></div>
    </c:when>
    <c:otherwise>
      <div class="notif-list">
        <c:forEach var="n" items="${notifications}">
          <article class="notif ${n.read ? '' : 'is-unread'}">
            <span class="notif__icon" aria-hidden="true">📅</span>
            <div class="notif__body">
              <p class="notif__title"><c:out value="${n.title}"/></p>
              <p class="notif__msg"><c:out value="${n.message}"/></p>
              <p class="notif__time"><c:out value="${n.timeText}"/><c:if test="${not n.read}"> · Chưa đọc</c:if></p>
            </div>
            <%-- Bấm vào thẻ = POST action=read: đánh dấu đã đọc rồi mở lịch hẹn liên quan --%>
            <form method="post" action="${ctx}/notifications">
              <input type="hidden" name="action" value="read">
              <input type="hidden" name="id" value="${n.notificationId}">
              <button class="notif__open" type="submit" aria-label="Mở: <c:out value="${n.title}"/>"></button>
            </form>
          </article>
        </c:forEach>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
