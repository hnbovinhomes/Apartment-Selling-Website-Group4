<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  Form đăng ký: chỉ gồm các cột của bảng users
    role       -> users.role ('CUSTOMER' | 'OWNER'), kèm thêm 1 dòng ở customers hoặc owners
    fullName   -> users.full_name
    phone      -> users.phone (và users.username, vì DB bắt username = phone)
    cccd       -> users.cccd (không bắt buộc, 9 hoặc 12 số)
    email      -> users.email
    password   -> users.password_hash (lưu thẳng mật khẩu)
  AuthServlet gửi sang: form.* (giữ lại khi nhập sai), error, next
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Đăng ký tài khoản</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/auth.css?v=7">
</head>
<body>
<main class="auth-page">
  <div class="auth-card">
    <section class="auth-side">
      <p class="auth-badge">Apartment sales and<br>transaction management</p>
      <a class="auth-brand" href="${ctx}/">▲ Apartment Management</a>
      <%-- 2 đoạn chữ, CSS hiện đoạn đúng với vai trò đang chọn --%>
      <div class="auth-text--customer">
        <h1>Tạo tài khoản khách hàng mới</h1>
        <p>Trở thành thành viên để dễ dàng giao dịch, quản lý căn hộ và nhận các tiện ích tốt nhất.</p>
      </div>
      <div class="auth-text--owner">
        <h1>Tạo tài khoản chủ căn hộ mới</h1>
        <p>Đăng tin bán hoặc cho thuê căn hộ, quản lý lịch xem nhà và khách quan tâm.</p>
      </div>
    </section>

    <section class="auth-main">
      <h2>Đăng ký thông tin</h2>
      <c:if test="${not empty error}"><p class="auth-alert" role="alert"><c:out value="${error}"/></p></c:if>

      <form method="post" action="${ctx}/auth">
        <input type="hidden" name="action" value="register">
        <input type="hidden" name="next" value="<c:out value="${next}"/>">

        <p class="role-label" id="roleLabel">Bạn đăng ký với vai trò</p>
        <div class="role-picker" role="radiogroup" aria-labelledby="roleLabel">
          <label class="role-option">
            <input type="radio" id="roleCustomer" name="role" value="CUSTOMER" ${form.role != 'OWNER' ? 'checked' : ''}>
            <span><b>Khách hàng</b><small>Tìm mua, thuê, đặt lịch xem</small></span>
          </label>
          <label class="role-option">
            <input type="radio" id="roleOwner" name="role" value="OWNER" ${form.role == 'OWNER' ? 'checked' : ''}>
            <span><b>Chủ căn hộ</b><small>Đăng tin bán, cho thuê</small></span>
          </label>
        </div>

        <label class="sr-only" for="fullName">Họ và tên đầy đủ</label>
        <input class="auth-input" id="fullName" name="fullName" maxlength="150" required autocomplete="name"
               placeholder="Họ và tên đầy đủ" value="<c:out value="${form.fullName}"/>">

        <label class="sr-only" for="phone">Số điện thoại liên hệ</label>
        <input class="auth-input" id="phone" name="phone" type="tel" maxlength="20" required autocomplete="tel"
               placeholder="Số điện thoại liên hệ" value="<c:out value="${form.phone}"/>">
        <p class="auth-hint">Số điện thoại cũng là tên đăng nhập của bạn.</p>

        <label class="sr-only" for="cccd">Số CCCD / CMND</label>
        <input class="auth-input" id="cccd" name="cccd" inputmode="numeric" maxlength="12"
               placeholder="Số CCCD / CMND (không bắt buộc)" value="<c:out value="${form.cccd}"/>">

        <label class="sr-only" for="email">Địa chỉ Email</label>
        <input class="auth-input" id="email" name="email" type="email" maxlength="150" required autocomplete="email"
               placeholder="Địa chỉ Email" value="<c:out value="${form.email}"/>">

        <label class="sr-only" for="password">Mật khẩu</label>
        <input class="auth-input" id="password" name="password" type="password" minlength="8" maxlength="72" required
               autocomplete="new-password" placeholder="Mật khẩu (tối thiểu 8 ký tự, có chữ và số)">

        <label class="sr-only" for="confirmPassword">Xác nhận lại mật khẩu</label>
        <input class="auth-input" id="confirmPassword" name="confirmPassword" type="password" minlength="8" maxlength="72" required
               autocomplete="new-password" placeholder="Xác nhận lại mật khẩu">

        <button class="auth-submit" type="submit">Hoàn tất đăng ký</button>
      </form>

      <c:url var="loginUrl" value="/auth"><c:param name="action" value="login"/><c:param name="next" value="${next}"/></c:url>
      <p class="auth-switch">Bạn đã có tài khoản? <a href="${loginUrl}">Đăng nhập ngay</a></p>
      <a class="auth-back" href="${ctx}/">← Về trang chủ</a>
    </section>
  </div>
</main>
</body>
</html>
