<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  ViewingServlet gửi sang:
    viewings (List<PropertyViewing>), tab, totalCount, pendingCount, confirmedCount, closedCount, message, error
  currentUser (AuthFilter): currentUser.owner = true -> giao diện chủ căn hộ, ngược lại là khách hàng
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Lịch hẹn xem nhà</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/account.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <div class="acc-head">
    <div>
      <h1 class="page__title">${currentUser.owner ? 'Lịch hẹn xem nhà' : 'Lịch hẹn của tôi'}</h1>
      <p class="acc-sub">
        <c:choose>
          <c:when test="${currentUser.owner}">Khách đặt lịch xem các căn của bạn. Hãy xác nhận hoặc từ chối các lịch đang chờ.</c:when>
          <c:otherwise>Các lịch xem nhà bạn đã đặt. Chủ căn hộ xác nhận xong, bạn sẽ nhận thông báo ở 🔔.</c:otherwise>
        </c:choose>
      </p>
    </div>
    <c:if test="${not currentUser.owner}"><a class="btn btn--outline" href="${ctx}/properties">+ Tìm căn để đặt lịch</a></c:if>
  </div>

  <c:if test="${not empty message}"><p class="alert alert--ok" role="status">✓ <c:out value="${message}"/></p></c:if>
  <c:if test="${not empty error}"><p class="alert alert--err" role="alert">⚠ <c:out value="${error}"/></p></c:if>

  <nav class="tabs" aria-label="Lọc theo trạng thái">
    <a class="tab ${tab == 'all' ? 'is-active' : ''}" href="${ctx}/viewings?status=all">Tất cả<b>${totalCount}</b></a>
    <a class="tab ${tab == 'pending' ? 'is-active' : ''}" href="${ctx}/viewings?status=pending">Chờ xác nhận<b>${pendingCount}</b></a>
    <a class="tab ${tab == 'confirmed' ? 'is-active' : ''}" href="${ctx}/viewings?status=confirmed">Đã xác nhận<b>${confirmedCount}</b></a>
    <a class="tab ${tab == 'closed' ? 'is-active' : ''}" href="${ctx}/viewings?status=closed">Đã kết thúc<b>${closedCount}</b></a>
  </nav>

  <c:choose>
    <c:when test="${empty viewings}">
      <div class="empty-box">
        <p>Chưa có lịch hẹn nào ở mục này.</p>
        <c:if test="${not currentUser.owner}"><a class="btn btn--primary" href="${ctx}/properties">Xem danh sách căn hộ</a></c:if>
      </div>
    </c:when>
    <c:otherwise>
      <div class="viewing-list">
        <c:forEach var="v" items="${viewings}">
          <%-- id="v123": thông báo bấm vào sẽ mở /viewings#v123 và cuộn đúng tới thẻ này --%>
          <article class="viewing" id="v${v.viewingId}">
            <div class="viewing__date">
              <b><c:out value="${v.startTime.dayOfMonth}"/></b>
              <small>Th<c:out value="${v.startTime.monthValue}"/>/<c:out value="${v.startTime.year}"/></small>
            </div>

            <div>
              <p class="viewing__title"><a href="${ctx}/properties?action=detail&id=${v.propertyId}"><c:out value="${v.propertyTitle}"/></a></p>
              <p class="viewing__meta">
                <span>🕒 <c:out value="${v.timeText}"/> · <c:out value="${v.dateText}"/></span>
                <span class="status ${v.statusClass}"><c:out value="${v.status}"/></span>
                <span>Mã lịch #<c:out value="${v.viewingId}"/></span>
              </p>
              <p class="viewing__meta">
                <c:choose>
                  <c:when test="${currentUser.owner}">
                    <span>👤 Khách: <b><c:out value="${v.customerName}"/></b></span>
                    <span>📞 <c:out value="${v.customerPhone}"/></span>
                  </c:when>
                  <c:otherwise>
                    <span>🏠 Chủ căn hộ: <b><c:out value="${v.ownerName}"/></b></span>
                    <%-- SĐT chủ căn hộ chỉ hiện khi lịch đã được xác nhận --%>
                    <c:if test="${v.confirmed}"><span>📞 <c:out value="${v.ownerPhone}"/></span></c:if>
                  </c:otherwise>
                </c:choose>
              </p>
              <c:if test="${not empty v.note}"><p class="viewing__note">📝 <c:out value="${v.note}"/></p></c:if>
              <c:if test="${not empty v.cancellationReason}"><p class="viewing__reason">Lý do: <c:out value="${v.cancellationReason}"/></p></c:if>
            </div>

            <%-- Các nút thao tác: mỗi nút là 1 form POST /viewings với action + id --%>
            <div class="viewing__actions">
              <c:choose>
                <c:when test="${currentUser.owner and v.pending}">
                  <form method="post" action="${ctx}/viewings">
                    <input type="hidden" name="action" value="confirm"><input type="hidden" name="id" value="${v.viewingId}">
                    <input type="hidden" name="status" value="${tab}">
                    <button class="btn btn--primary" type="submit">✓ Xác nhận</button>
                  </form>
                  <details class="reason-box">
                    <summary class="btn btn--danger">Từ chối</summary>
                    <form method="post" action="${ctx}/viewings">
                      <input type="hidden" name="action" value="reject"><input type="hidden" name="id" value="${v.viewingId}">
                      <input type="hidden" name="status" value="${tab}">
                      <textarea class="input textarea" name="reason" maxlength="500" placeholder="Lý do từ chối (không bắt buộc)"></textarea>
                      <button class="btn btn--danger-fill" type="submit">Xác nhận từ chối</button>
                    </form>
                  </details>
                </c:when>
                <c:when test="${currentUser.owner and v.confirmed}">
                  <form method="post" action="${ctx}/viewings">
                    <input type="hidden" name="action" value="complete"><input type="hidden" name="id" value="${v.viewingId}">
                    <input type="hidden" name="status" value="${tab}">
                    <button class="btn btn--primary" type="submit">Đã xem xong</button>
                  </form>
                  <details class="reason-box">
                    <summary class="btn btn--danger">Hủy lịch</summary>
                    <form method="post" action="${ctx}/viewings">
                      <input type="hidden" name="action" value="cancel"><input type="hidden" name="id" value="${v.viewingId}">
                      <input type="hidden" name="status" value="${tab}">
                      <textarea class="input textarea" name="reason" maxlength="500" placeholder="Lý do hủy (không bắt buộc)"></textarea>
                      <button class="btn btn--danger-fill" type="submit">Xác nhận hủy</button>
                    </form>
                  </details>
                </c:when>
                <c:when test="${not currentUser.owner and (v.pending or v.confirmed)}">
                  <details class="reason-box">
                    <summary class="btn btn--danger">Hủy lịch</summary>
                    <form method="post" action="${ctx}/viewings">
                      <input type="hidden" name="action" value="cancel"><input type="hidden" name="id" value="${v.viewingId}">
                      <input type="hidden" name="status" value="${tab}">
                      <textarea class="input textarea" name="reason" maxlength="500" placeholder="Lý do hủy (không bắt buộc)"></textarea>
                      <button class="btn btn--danger-fill" type="submit">Xác nhận hủy</button>
                    </form>
                  </details>
                </c:when>
              </c:choose>
            </div>
          </article>
        </c:forEach>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
