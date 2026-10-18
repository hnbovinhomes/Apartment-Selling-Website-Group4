<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" session="false" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Đặt lịch xem căn hộ</title>
  <link rel="stylesheet" href="${ctx}/css/base.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/layout.css?v=6">
  <link rel="stylesheet" href="${ctx}/css/appointment.css?v=6">
</head>
<body id="top">
<jsp:include page="/WEB-INF/views/partials/header.jsp"/>

<main class="container page appt">
  <p class="appt-breadcrumb"><a href="${ctx}/">Trang chủ</a> / <a href="${ctx}/properties">Căn hộ</a> / <strong>Đặt lịch xem nhà</strong></p>
  <h1 class="page__title">Đặt lịch xem căn hộ</h1>
  <p class="appt-sub">Chọn thời gian phù hợp và để chúng tôi giúp bạn khám phá ngôi nhà tương lai.</p>

  <c:if test="${not empty booked}">
    <%-- booked là JavaBean PropertyViewing vừa tạo --%>
    <div class="alert alert--ok">✓ <b>Đã gửi yêu cầu đặt lịch!</b> Mã lịch hẹn #<c:out value="${booked.viewingId}"/> —
      <c:out value="${booked.fullDateText}"/>, <c:out value="${booked.timeText}"/>. Trạng thái: <b><c:out value="${booked.status}"/></b>.
      Bạn sẽ nhận thông báo ở 🔔 khi chủ căn hộ xác nhận. <a href="${ctx}/viewings#v${booked.viewingId}"><u>Xem lịch hẹn của tôi</u></a></div>
  </c:if>
  <c:if test="${not empty error}">
    <div class="alert alert--err">⚠ <c:out value="${error}"/></div>
  </c:if>

  <div class="appt-layout">
    <section class="appt-card">
      <div class="appt-step"><span class="appt-step__no">01</span>
        <div><h2>Chọn ngày &amp; giờ xem</h2><p>Vui lòng chọn một khung giờ còn trống.</p></div></div>

      <div class="cal-head">
        <h3><c:out value="${monthTitle}"/></h3>
        <div class="cal-nav">
          <c:choose>
            <c:when test="${empty prevHref}"><span class="cal-nav__btn is-disabled">‹</span></c:when>
            <c:otherwise><a class="cal-nav__btn" href="<c:out value='${prevHref}'/>">‹</a></c:otherwise>
          </c:choose>
          <c:choose>
            <c:when test="${empty nextHref}"><span class="cal-nav__btn is-disabled">›</span></c:when>
            <c:otherwise><a class="cal-nav__btn" href="<c:out value='${nextHref}'/>">›</a></c:otherwise>
          </c:choose>
        </div>
      </div>

      <div class="cal-grid">
        <div class="cal-dow">T2</div><div class="cal-dow">T3</div><div class="cal-dow">T4</div><div class="cal-dow">T5</div>
        <div class="cal-dow">T6</div><div class="cal-dow">T7</div><div class="cal-dow">CN</div>
        <%-- cells: List<DaySlot> (JavaBean), slots: List<SlotInfo> (JavaBean) do AppointmentService tạo --%>
        <c:forEach var="cell" items="${cells}">
          <c:choose>
            <c:when test="${cell.blank}"><div></div></c:when>
            <c:when test="${empty cell.href}"><span class="cal-day ${cell.cls}"><b>${cell.day}</b><small>${cell.label}</small></span></c:when>
            <c:otherwise><a class="cal-day ${cell.cls}" href="<c:out value='${cell.href}'/>"><b>${cell.day}</b><small>${cell.label}</small></a></c:otherwise>
          </c:choose>
        </c:forEach>
      </div>

      <h3 class="slot-title">Khung giờ có sẵn <span>· <c:out value="${dateText}"/></span></h3>
      <div class="slot-grid">
        <c:forEach var="slot" items="${slots}">
          <c:choose>
            <c:when test="${empty slot.href}"><span class="slot ${slot.cls}">${slot.time}</span></c:when>
            <c:otherwise><a class="slot ${slot.cls}" href="<c:out value='${slot.href}'/>">${slot.time}</a></c:otherwise>
          </c:choose>
        </c:forEach>
      </div>

      <hr class="appt-hr">
      <c:choose>
        <%-- 1. Khách hàng đã đăng nhập: hiện form đặt lịch --%>
        <c:when test="${canBook}">
          <form method="post" action="${ctx}/appointments">
            <input type="hidden" name="propertyId" value="${property.propertyId}">
            <input type="hidden" name="date" value="<c:out value='${selectedDate}'/>">
            <input type="hidden" name="time" value="<c:out value='${selectedTime}'/>">

            <div class="appt-step"><span class="appt-step__no">02</span>
              <div><h2>Thông tin liên hệ</h2><p>Lấy sẵn từ tài khoản của bạn, có thể sửa. Chủ căn hộ sẽ xác nhận lịch.</p></div></div>

            <%-- name = tên cột trong property_viewings: customer_name, customer_phone, note --%>
            <div class="field-row">
              <div class="field"><label class="field__label" for="customerName">Họ và tên *</label>
                <input class="input" id="customerName" name="customerName" maxlength="150" required placeholder="Nguyễn Văn A" value="<c:out value='${form.customerName}'/>"></div>
              <div class="field"><label class="field__label" for="customerPhone">Số điện thoại *</label>
                <input class="input" id="customerPhone" name="customerPhone" type="tel" maxlength="20" required placeholder="09xx xxx xxx" value="<c:out value='${form.customerPhone}'/>"></div>
            </div>
            <div class="field"><label class="field__label" for="note">Ghi chú <small>(không bắt buộc)</small></label>
              <textarea class="input textarea" id="note" name="note" maxlength="1000" placeholder="Ví dụ: Tôi muốn tìm hiểu thêm về phí quản lý..."><c:out value="${form.note}"/></textarea></div>

            <button class="btn btn--primary btn--block appt-submit" type="submit" ${empty selectedTime ? 'disabled' : ''}>Gửi yêu cầu đặt lịch</button>
            <c:if test="${empty selectedTime}"><p class="appt-hint">Hãy chọn một khung giờ ở trên để tiếp tục.</p></c:if>
            <p class="appt-privacy">Lịch hẹn ở trạng thái "Chờ xác nhận" cho tới khi chủ căn hộ đồng ý.</p>
          </form>
        </c:when>
        <%-- 2. Chủ căn hộ: không đặt lịch được (DB chỉ cho customer_id là tài khoản CUSTOMER) --%>
        <c:when test="${isOwnerViewer}">
          <div class="appt-login">
            <p>Bạn đang đăng nhập bằng tài khoản <b>Chủ căn hộ</b>. Chỉ tài khoản khách hàng mới đặt được lịch xem nhà.</p>
            <a class="btn btn--outline" href="${ctx}/viewings">Xem lịch hẹn của các căn của bạn</a>
          </div>
        </c:when>
        <%-- 3. Chưa đăng nhập: mời đăng nhập, xong quay lại đúng trang này --%>
        <c:otherwise>
          <div class="appt-login">
            <p>Vui lòng <b>đăng nhập bằng tài khoản khách hàng</b> để đặt lịch xem căn hộ này.</p>
            <a class="btn btn--primary" href="<c:out value='${loginUrl}'/>">Đăng nhập để đặt lịch</a>
            <c:url var="registerUrl" value="/auth"><c:param name="action" value="register"/><c:param name="next" value="/appointments?propertyId=${property.propertyId}"/></c:url>
            <a class="btn btn--outline" href="${registerUrl}">Tạo tài khoản khách hàng</a>
          </div>
        </c:otherwise>
      </c:choose>
    </section>

    <aside class="appt-side">
      <div class="appt-card appt-prop">
        <div class="appt-prop__img"><img src="<c:url value='${property.thumbnailUrl}'/>" alt="<c:out value='${property.title}'/>">
          <span class="appt-prop__badge">Căn hộ nổi bật</span></div>
        <h3 class="appt-prop__title"><c:out value="${property.title}"/></h3>
        <p class="appt-prop__loc">📍 <c:out value="${property.district}"/>, <c:out value="${property.city}"/></p>
        <p class="appt-prop__price"><c:out value="${property.priceText}"/> <small>${property.rent ? 'Giá thuê' : 'Giá bán'}</small></p>
        <div class="appt-prop__specs">
          <div><b>${property.bedrooms}</b><small>Phòng ngủ</small></div>
          <div><b>${property.bathrooms}</b><small>Phòng tắm</small></div>
          <div><b><c:out value="${property.area}"/> m²</b><small>Diện tích</small></div>
        </div>
        <c:if test="${not empty ownerAccount}">
          <div class="appt-agent"><span class="appt-agent__avatar"><c:out value="${ownerAccount.initial}"/></span>
            <div><b><c:out value="${ownerAccount.fullName}"/></b><small>Chủ căn hộ · sẽ xác nhận lịch hẹn</small></div></div>
        </c:if>
        <div class="appt-summary">
          <h4>Tóm tắt lịch hẹn</h4>
          <p><span>Ngày xem</span><b><c:out value="${dateText}"/></b></p>
          <p><span>Giờ xem</span><b><c:out value="${timeText}"/></b></p>
          <p><span>Thời lượng</span><b>Khoảng 30 phút</b></p>
        </div>
        <p class="appt-perks">✓ Miễn phí tham quan · Không bắt buộc đặt cọc · Chủ căn hộ sẽ xác nhận qua thông báo.</p>
      </div>
    </aside>
  </div>
</main>

<jsp:include page="/WEB-INF/views/partials/footer.jsp"/>
</body>
</html>
