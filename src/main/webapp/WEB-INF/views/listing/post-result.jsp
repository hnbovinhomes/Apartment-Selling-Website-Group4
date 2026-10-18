<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Đã nhận dữ liệu</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
</head>
<body>
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>
<main class="container page">
  <h1 class="page__title">Server đã nhận được dữ liệu form</h1>
  <p>Đây là bước đầu của chức năng lưu. Backend sẽ ghi các giá trị dưới đây vào database.</p>
  <ul style="margin:16px 0 24px;line-height:1.9">
    <c:forEach var="it" items="${fields}"><li><b><c:out value="${it.name}"/></b>: <c:out value="${it.value}"/></li></c:forEach>
  </ul>
  <a class="btn btn--primary" href="${ctx}/postings?action=create">Quay lại form</a>
</main>
<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
