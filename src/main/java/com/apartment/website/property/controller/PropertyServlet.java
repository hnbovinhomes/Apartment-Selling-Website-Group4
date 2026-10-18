package com.apartment.website.property.controller;

import com.apartment.website.common.exception.ReviewException;
import com.apartment.website.common.filter.AuthFilter;
import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.interaction.dto.ReviewSummary;
import com.apartment.website.interaction.entity.Review;
import com.apartment.website.interaction.service.ReviewService;
import com.apartment.website.property.dto.PageResult;
import com.apartment.website.property.dto.PropertyFilter;
import com.apartment.website.property.entity.Property;
import com.apartment.website.property.service.PropertyService;
import com.apartment.website.user.entity.Owner;
import com.apartment.website.user.entity.User;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Điều hướng bằng tham số action:
 *  GET  /properties                          -> danh sách (lọc + phân trang)  -> views/property/list.jsp
 *  GET  /properties?action=detail&id=3       -> chi tiết căn id 3              -> views/property/detail.jsp
 *  POST /properties  (action=review, id=3)   -> khách hàng đã đăng nhập gửi đánh giá, xong redirect về trang chi tiết
 * URL /properties khai báo trong web.xml.
 */
public class PropertyServlet extends HttpServlet {
    private PropertyService propertyService;
    private ReviewService reviewService;

    @Override
    public void init() {
        propertyService = (PropertyService) getServletContext().getAttribute(AppContextListener.PROPERTY_SERVICE);
        reviewService = (ReviewService) getServletContext().getAttribute(AppContextListener.REVIEW_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        if (action == null || action.isEmpty() || action.equals("list")) {
            showList(request, response);
        } else if (action.equals("detail")) {
            showDetail(request, response);
        } else {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        if ("review".equals(action)) {
            submitReview(request, response);
        } else {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
        }
    }

    // ===================== action=list =====================

    private void showList(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        // 1. Đọc các ô lọc trên URL
        String keyword = getText(request, "keyword");
        String district = getText(request, "district");
        String price = getText(request, "price");
        String type = "SALE";
        if ("RENT".equalsIgnoreCase(getText(request, "type"))) {
            type = "RENT";
        }
        Integer bedrooms = toInt(request.getParameter("bedrooms"));
        Integer pageParam = toInt(request.getParameter("page"));
        int page = 1;
        if (pageParam != null && pageParam > 1) {
            page = pageParam;
        }

        // 2. Gọi Service lấy 1 trang kết quả
        PropertyFilter filter = new PropertyFilter();
        filter.setKeyword(keyword);
        filter.setDistrict(district);
        filter.setBedrooms(bedrooms);
        filter.setPrice(price);
        filter.setType(type);
        PageResult<Property> result = propertyService.search(filter, page);
        // gõ page quá lớn -> lùi về trang cuối
        if (page > result.getTotalPages()) {
            page = result.getTotalPages();
            result = propertyService.search(filter, page);
        }

        // 3. Danh sách quận cho ô chọn (list.jsp tự đánh dấu quận đang chọn)
        List<String> districts = propertyService.districts();

        // 4. Link phân trang giữ nguyên bộ lọc, chỉ đổi số trang ở cuối
        String bedroomsText = "";
        if (bedrooms != null) {
            bedroomsText = String.valueOf(bedrooms);
        }
        String baseUrl = request.getContextPath() + "/properties?action=list"
                + "&keyword=" + encode(keyword)
                + "&district=" + encode(district)
                + "&price=" + encode(price)
                + "&type=" + type
                + "&bedrooms=" + bedroomsText
                + "&page=";

        // 5. Gửi dữ liệu sang JSP
        request.setAttribute("active", "list");
        request.setAttribute("type", type);
        request.setAttribute("properties", result.getItems());
        request.setAttribute("total", result.getTotal());
        request.setAttribute("noResult", result.getItems().isEmpty());
        request.setAttribute("districts", districts);
        request.setAttribute("district", district);
        // "hiển thị from–to": PageResult (JavaBean) tự tính
        request.setAttribute("from", result.getFrom());
        request.setAttribute("to", result.getTo());
        request.setAttribute("totalPages", result.getTotalPages());
        request.setAttribute("pages", propertyService.pageLinks(baseUrl, page, result.getTotalPages()));
        View.forward(request, response, "property/list");
    }

    // ===================== action=detail =====================

    private void showDetail(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        // 1. Lấy id trên URL rồi tìm căn
        Long id = toLong(request.getParameter("id"));
        if (id == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }
        Property property = propertyService.findById(id);
        if (property == null) {
            // web.xml sẽ hiện 404.jsp
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        // 2. Ảnh: ảnh lớn là ảnh thứ ?img=..., các ảnh nhỏ là link đổi ?img (detail.jsp tự ghép link)
        List<String> imageUrls = property.getImageUrls();
        if (imageUrls.isEmpty()) {
            imageUrls = new ArrayList<String>();
            imageUrls.add(Property.NO_IMAGE);
        }
        int selected = 0;
        Integer imgParam = toInt(request.getParameter("img"));
        if (imgParam != null && imgParam > 0 && imgParam < imageUrls.size()) {
            selected = imgParam;
        }

        // 3. Căn tương tự: cùng quận và khu vực khác
        List<Property> sameDistrict = propertyService.sameDistrict(property);
        List<Property> otherDistrict = propertyService.otherDistrict(property, sameDistrict.size());

        // 4. Chủ sở hữu (có thể chưa có)
        Owner owner = propertyService.ownerOf(property.getPropertyId());
        int ownerListings = 0;
        if (owner != null) {
            ownerListings = propertyService.activeListingCount(owner.getOwnerId());
        }

        // 5. Đánh giá
        List<Review> reviews = reviewService.reviews(property.getPropertyId());
        ReviewSummary reviewSummary = reviewService.summary(reviews);
        // form đánh giá (JavaBean Review): lần đầu mở trang thì mặc định chọn 5 sao
        if (request.getAttribute("reviewForm") == null) {
            Review defaultForm = new Review();
            defaultForm.setRating(Review.MAX_RATING);
            request.setAttribute("reviewForm", defaultForm);
        }

        // 6. Gửi dữ liệu sang JSP
        request.setAttribute("active", "list");
        request.setAttribute("property", property);
        request.setAttribute("mainImage", imageUrls.get(selected));
        request.setAttribute("images", imageUrls);
        request.setAttribute("selectedImage", selected);
        request.setAttribute("sameDistrict", sameDistrict);
        request.setAttribute("otherDistrict", otherDistrict);
        request.setAttribute("owner", owner);
        request.setAttribute("ownerListings", ownerListings);
        request.setAttribute("reviews", reviews);
        request.setAttribute("reviewSummary", reviewSummary);
        // "created" | "updated" sau khi gửi đánh giá thành công
        request.setAttribute("reviewStatus", getText(request, "review"));
        View.forward(request, response, "property/detail");
    }

    // ===================== action=review (POST) =====================

    private void submitReview(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        Long id = toLong(request.getParameter("id"));
        if (id == null || propertyService.findById(id) == null) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        // chưa đăng nhập -> đăng nhập xong quay lại trang chi tiết căn này
        User user = AuthFilter.getLoginUser(request);
        if (user == null) {
            String next = "/properties?action=detail&id=" + id;
            response.sendRedirect(request.getContextPath() + "/auth?action=login&next=" + encode(next));
            return;
        }

        String rating = request.getParameter("rating");
        String comment = request.getParameter("comment");

        try {
            boolean created = reviewService.submit(id, user, rating, comment);
            String status;
            if (created) {
                status = "created";
            } else {
                status = "updated";
            }
            // redirect (Post/Redirect/Get) để F5 không gửi lại form; #reviews cuộn thẳng xuống phần đánh giá
            response.sendRedirect(request.getContextPath() + "/properties?action=detail&id=" + id
                    + "&review=" + status + "#reviews");
            return;
        } catch (ReviewException e) {
            request.setAttribute("reviewError", e.getMessage());
        }

        // Dữ liệu sai -> hiện lại trang chi tiết, giữ lại những gì người dùng đã nhập (gói vào JavaBean Review)
        Review form = new Review();
        Integer ratingValue = toInt(rating);
        if (ratingValue != null) {
            form.setRating(ratingValue);
        }
        form.setComment(getText(request, "comment"));
        request.setAttribute("reviewForm", form);
        showDetail(request, response);
    }

    // ===================== hàm phụ =====================

    /** Tham số không có thì trả về chuỗi rỗng thay vì null. */
    private static String getText(HttpServletRequest request, String name) {
        String value = request.getParameter(name);
        if (value == null) {
            return "";
        }
        return value;
    }

    private static Integer toInt(String text) {
        if (text == null) {
            return null;
        }
        try {
            return Integer.parseInt(text.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Long toLong(String text) {
        if (text == null) {
            return null;
        }
        try {
            return Long.parseLong(text.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String encode(String text) {
        return URLEncoder.encode(text, StandardCharsets.UTF_8);
    }
}
