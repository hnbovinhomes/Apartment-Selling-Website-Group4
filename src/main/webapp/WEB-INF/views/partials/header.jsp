<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- currentUser, unreadCount do AuthFilter đặt cho mọi request. Chưa đăng nhập thì currentUser rỗng. --%>
<header class="header">
  <div class="container navbar">
    <a href="${ctx}/" class="logo"><div class="logo-icon">⌂</div><span>Apartment</span></a>
    <nav class="nav-menu">
      <a href="${ctx}/" class="${active == 'home' ? 'active' : ''}">Trang chủ</a>
      <a href="${ctx}/properties" class="${active == 'list' ? 'active' : ''}">Danh sách căn hộ</a>
      <%-- Chủ căn hộ: Đăng tin + Quản lý tin của mình. Admin: Quản lý tin = rà soát mọi tin. Khách hàng: không thấy --%>
      <c:if test="${currentUser.owner}">
        <a href="${ctx}/postings?action=create" class="${active == 'post' ? 'active' : ''}">Đăng tin</a>
      </c:if>
      <c:if test="${currentUser.owner or currentUser.admin}">
        <a href="${ctx}/postings" class="${active == 'manage' ? 'active' : ''}">Quản lý tin</a>
      </c:if>
      <a href="${ctx}/comparisons" class="${active == 'compare' ? 'active' : ''}">So sánh</a>
      <%-- Lịch hẹn chỉ có ở khách hàng (người đặt) và chủ căn hộ (người xác nhận) --%>
      <c:if test="${currentUser.owner or currentUser.customer}">
        <a href="${ctx}/viewings" class="${active == 'viewings' ? 'active' : ''}">Lịch hẹn</a>
      </c:if>
      <a href="${ctx}/about" class="${active == 'about' ? 'active' : ''}">Về chúng tôi</a>
    </nav>
    <div class="header-actions">
      <c:choose>
        <c:when test="${not empty currentUser}">
          <a class="notification-btn ${active == 'notifications' ? 'is-active' : ''}" href="${ctx}/notifications"
             title="Thông báo" aria-label="Thông báo (${unreadCount} chưa đọc)">🔔<c:if test="${unreadCount > 0}"><span class="notification-badge">${unreadCount > 9 ? '9+' : unreadCount}</span></c:if></a>
          <span class="user-chip">
            <span class="user-chip__avatar" aria-hidden="true"><c:out value="${currentUser.initial}"/></span>
            <span class="user-chip__text"><b><c:out value="${currentUser.fullName}"/></b><small><c:out value="${currentUser.roleText}"/></small></span>
          </span>
          <a href="${ctx}/auth?action=logout" class="logout-btn">Đăng xuất</a>
        </c:when>
        <c:otherwise>
          <a href="${ctx}/auth?action=register" class="register-link">Đăng ký</a>
          <a href="${ctx}/auth?action=login" class="login-btn">Đăng nhập</a>
        </c:otherwise>
      </c:choose>
    </div>
  </div>
</header>
