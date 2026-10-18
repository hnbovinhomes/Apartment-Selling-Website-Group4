<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<footer class="footer">
  <div class="container footer-content">
    <div class="footer-brand">
      <div class="logo footer-logo"><div class="logo-icon">⌂</div><span>Apartment</span></div>
      <p>Nền tảng hỗ trợ tìm kiếm và giao dịch bất động sản trực tuyến.</p>
    </div>
    <div class="footer-column"><h4>Khám phá</h4>
      <a href="${ctx}/properties">Danh sách căn hộ</a>
      <a href="${ctx}/comparisons">So sánh</a>
      <c:if test="${currentUser.owner or currentUser.customer}"><a href="${ctx}/viewings">Lịch hẹn</a></c:if>
    </div>
    <%-- Cột "Chủ sở hữu" chỉ hiện cho Chủ căn hộ; khách hàng / chưa đăng nhập thấy cột "Tài khoản" --%>
    <c:choose>
      <c:when test="${currentUser.owner}">
        <div class="footer-column"><h4>Chủ sở hữu</h4>
          <a href="${ctx}/postings?action=create">Đăng tin</a>
          <a href="${ctx}/postings">Quản lý tin</a>
          <a href="${ctx}/notifications">Thông báo</a>
        </div>
      </c:when>
      <c:when test="${currentUser.admin}">
        <div class="footer-column"><h4>Quản trị</h4>
          <a href="${ctx}/postings">Rà soát tin đăng</a>
          <a href="${ctx}/notifications">Thông báo</a>
        </div>
      </c:when>
      <c:when test="${not empty currentUser}">
        <div class="footer-column"><h4>Tài khoản</h4>
          <a href="${ctx}/viewings">Lịch hẹn của tôi</a>
          <a href="${ctx}/notifications">Thông báo</a>
        </div>
      </c:when>
      <c:otherwise>
        <div class="footer-column"><h4>Tài khoản</h4>
          <a href="${ctx}/auth?action=login">Đăng nhập</a>
          <a href="${ctx}/auth?action=register">Đăng ký khách hàng</a>
          <a href="${ctx}/auth?action=register&role=OWNER">Đăng ký chủ căn hộ</a>
        </div>
      </c:otherwise>
    </c:choose>
    <div class="footer-column"><h4>Hỗ trợ</h4>
      <a href="${ctx}/about">Về chúng tôi</a>
      <a href="${ctx}/contact">Liên hệ</a></div>
  </div>
  <div class="footer-bottom"><div class="container">© 2026 Apartment Selling Website. All rights reserved.</div></div>
</footer>
