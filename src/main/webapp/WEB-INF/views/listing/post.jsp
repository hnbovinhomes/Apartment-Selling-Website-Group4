<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Đăng tin bất động sản</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/listing-post.css?v=6">
</head>
<body id="top">
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page">
  <div class="post-card">
    <h1 class="page__title">Đăng tin Bất động sản</h1>
    
    <form class="post-form" id="postForm" action="${ctx}/postings" method="post">
      <input type="hidden" name="action" value="create">

      <section class="post-section post-section--basic">
        <h2 class="post-section__title">1. Thông tin cơ bản</h2>
        <div class="field"><span class="field__label">Loại hình</span>
          <div class="radio-group">
            <label><input type="radio" name="type" value="SALE" checked> Bán</label>
            <label><input type="radio" name="type" value="RENT"> Cho thuê</label>
          </div></div>
        <div class="field"><label class="field__label" for="title">Tiêu đề bài viết</label>
          <input class="input" id="title" name="title" placeholder="VD: Bán căn hộ 2PN view sông mát mẻ..."></div>
      </section>

      <section class="post-section post-section--location">
        <h2 class="post-section__title">2. Thông tin vị trí</h2>
        <div class="field-row">
          <div class="field"><label class="field__label" for="province">Tỉnh/Thành phố</label>
            <select class="input" id="province" name="province"><option>Tỉnh/Thành phố</option></select></div>
          <div class="field"><label class="field__label" for="district">Quận/Huyện</label>
            <select class="input" id="district" name="district"><option>Quận/Huyện</option></select></div>
        </div>
        <div class="field"><label class="field__label" for="ward">Phường/Xã</label>
          <select class="input" id="ward" name="ward"><option>Phường/Xã</option></select></div>
        <div class="field"><input class="input" id="address" name="address" placeholder="Địa chỉ chi tiết"></div>
        <div class="field-row">
          <div class="field"><label class="field__label" for="bedrooms">Số phòng ngủ</label>
            <select class="input" id="bedrooms" name="bedrooms"><option>1</option><option>2</option><option selected>3</option></select></div>
          <div class="field"><label class="field__label" for="bathrooms">Số phòng tắm</label>
            <select class="input" id="bathrooms" name="bathrooms"><option selected>1</option><option>2</option><option>3</option></select></div>
        </div>
      </section>

      <section class="post-section post-section--feature">
        <h2 class="post-section__title">3. Đặc điểm căn hộ</h2>
        <div class="field-row">
          <div class="field"><label class="field__label" for="area">Diện tích (m²)</label>
            <input class="input" id="area" name="area" type="number" placeholder="m²"></div>
          <div class="field"><label class="field__label" for="price">Mức giá (VNĐ)</label>
            <input class="input" id="price" name="price" type="number" placeholder="Mức giá (VNĐ)"></div>
          <div class="field"><label class="field__label" for="direction">Hướng ban công</label>
            <select class="input" id="direction" name="direction"><option>Đông</option><option>Tây</option><option>Nam</option><option>Bắc</option></select></div>
          <div class="field"><label class="field__label" for="furniture">Tình trạng nội thất</label>
            <select class="input" id="furniture" name="furniture"><option>Trống</option><option>Cơ bản</option><option>Đầy đủ</option></select></div>
        </div>
      </section>

      <section class="post-section post-section--media">
        <h2 class="post-section__title">4. Hình ảnh và Video</h2>
        <label class="upload-box" id="uploadBox">
          <span class="upload-box__icon">📷</span>
          <span>Kéo thả hình ảnh vào đây hoặc<br>Nhấn để tải lên</span>
          <input type="file" id="fileInput" name="files" multiple accept="image/*,video/*" hidden>
        </label>
        <div class="thumb-row" id="previewList">
          <img class="thumb-row__item" src="${ctx}/images/apartment-sample.jpg" alt="">
          <img class="thumb-row__item" src="${ctx}/images/apartment-sample.jpg" alt="">
          <img class="thumb-row__item" src="${ctx}/images/apartment-sample.jpg" alt="">
          <img class="thumb-row__item" src="${ctx}/images/apartment-sample.jpg" alt="">
        </div>
      </section>

      <section class="post-section post-section--desc">
        <h2 class="post-section__title">5. Mô tả chi tiết</h2>
        <textarea class="input textarea" id="description" name="description" placeholder="Mô tả các tiện ích, đặc điểm nổi bật..."></textarea>
      </section>

      <section class="post-section post-section--contact">
        <h2 class="post-section__title">6. Thông tin liên hệ</h2>
        <p class="post-section__hint">(Tự động điền nếu đã đăng nhập)</p>
        <div class="field"><input class="input" name="contactName" placeholder="Tên người liên hệ"></div>
        <div class="field"><label class="field__label" for="phone">Số điện thoại</label>
          <input class="input" id="phone" name="phone" type="tel" placeholder="Số điện thoại"></div>
        <div class="form-actions">
          <button class="btn btn--gray" type="reset">Hủy</button>
          <button class="btn btn--primary" type="submit">Đăng tin ngay</button>
        </div>
      </section>
    </form>
  </div>
</main>
<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
