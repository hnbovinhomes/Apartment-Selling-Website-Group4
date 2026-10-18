<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- AuthServlet gửi sang: phoneOrEmail (giữ lại khi nhập sai hoặc đọc từ cookie "rememberPhone"), remember, error, next --%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Đăng nhập</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/auth.css?v=7">
</head>
<body>
<main class="auth-page">
  <div class="auth-card">
    <section class="auth-side">
      <p class="auth-badge">Apartment sales and<br>transaction management</p>
      <a class="auth-brand" href="${ctx}/">▲ Apartment Management</a>
      <h1>Khám phá căn hộ hoàn hảo cho cuộc sống của bạn</h1>
      <p>Hệ thống quản lý mua bán, tìm kiếm và giao dịch bất động sản chuyên nghiệp.</p>
    </section>

    <section class="auth-main">
      <h2>Đăng nhập</h2>
      <c:if test="${not empty error}"><p class="auth-alert" role="alert"><c:out value="${error}"/></p></c:if>

      <%-- POST /auth với action=login. Đăng nhập bằng users.phone hoặc users.email --%>
      <form method="post" action="${ctx}/auth">
        <input type="hidden" name="action" value="login">
        <input type="hidden" name="next" value="<c:out value="${next}"/>">

        <label class="sr-only" for="phoneOrEmail">Số điện thoại hoặc email</label>
        <input class="auth-input" id="phoneOrEmail" name="phoneOrEmail" required autocomplete="username"
               placeholder="SĐT chính hoặc email" value="<c:out value="${phoneOrEmail}"/>">

        <label class="sr-only" for="password">Mật khẩu</label>
        <input class="auth-input" id="password" name="password" type="password" required autocomplete="current-password"
               placeholder="Mật khẩu">

        <%-- tick vào thì AuthServlet lưu SĐT/email vào Cookie "rememberPhone" 30 ngày (KHÔNG lưu mật khẩu) --%>
        <label class="auth-remember">
          <input type="checkbox" name="remember" value="1" ${remember ? 'checked' : ''}> Ghi nhớ số điện thoại / email
        </label>

        <button class="auth-submit" type="submit">Đăng nhập</button>
      </form>

      <c:url var="registerUrl" value="/auth"><c:param name="action" value="register"/><c:param name="next" value="${next}"/></c:url>
      <p class="auth-switch">Bạn chưa có tài khoản? <a href="${registerUrl}">Đăng ký</a></p>
      <a class="auth-back" href="${ctx}/">← Về trang chủ</a>
    </section>
  </div>
</main>
</body>
</html>
