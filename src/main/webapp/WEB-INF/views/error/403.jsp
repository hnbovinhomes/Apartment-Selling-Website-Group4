<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Không có quyền truy cập</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>
<main class="container page" style="text-align:center;padding:80px 16px">
  <h1 style="font-size:64px;color:var(--green)">403</h1>
  <p style="margin:12px 0 24px">Tài khoản của bạn không có quyền xem trang này.</p>
  <a class="btn btn--primary" href="${ctx}/">Về trang chủ</a>
</main>
<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
