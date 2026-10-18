package com.apartment.website.interaction.controller;

import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.property.entity.Property;
import com.apartment.website.property.service.PropertyService;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * /comparisons
 *  GET                      -> hiện bảng so sánh các căn đã chọn (lưu trong session) -> views/comparison/compare.jsp
 *  POST action=add&id=5     -> thêm căn 5 vào danh sách so sánh (tối đa 3 căn), rồi redirect về GET
 *  POST action=remove&id=5  -> bỏ căn 5
 *  POST action=clear        -> xóa hết
 */
public class ComparisonServlet extends HttpServlet {
    public static final int MAX_ITEMS = 3;
    private static final String SESSION_KEY = "compareIds";

    private PropertyService propertyService;

    @Override
    public void init() {
        propertyService = (PropertyService) getServletContext().getAttribute(AppContextListener.PROPERTY_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(true);
        List<Property> items = new ArrayList<Property>();

        synchronized (session) {
            List<Long> ids = getIds(session);
            List<Long> validIds = new ArrayList<Long>();
            for (int i = 0; i < ids.size(); i++) {
                Long id = ids.get(i);
                Property property = propertyService.findById(id);
                // căn đã bị xóa khỏi DB thì tự bỏ ra khỏi danh sách
                if (property != null) {
                    items.add(property);
                    validIds.add(id);
                }
            }
            ids.clear();
            ids.addAll(validIds);
        }

        // các ô trống còn lại để hiện nút "+ Thêm căn hộ"
        List<Integer> emptySlots = new ArrayList<Integer>();
        for (int i = items.size(); i < MAX_ITEMS; i++) {
            emptySlots.add(i + 1);
        }

        request.setAttribute("active", "compare");
        request.setAttribute("items", items);
        request.setAttribute("emptySlots", emptySlots);
        request.setAttribute("canAdd", items.size() < MAX_ITEMS);
        request.setAttribute("full", "1".equals(request.getParameter("full")));
        request.setAttribute("maxItems", MAX_ITEMS);
        View.forward(request, response, "comparison/compare");
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        String action = request.getParameter("action");
        Long id = toLong(request.getParameter("id"));
        boolean full = false;

        HttpSession session = request.getSession(true);
        synchronized (session) {
            List<Long> ids = getIds(session);
            if ("add".equals(action) && id != null) {
                if (!ids.contains(id)) {
                    if (ids.size() >= MAX_ITEMS) {
                        full = true;
                    } else if (propertyService.findById(id) != null) {
                        ids.add(id);
                    }
                }
            } else if ("remove".equals(action) && id != null) {
                // id là Long (object) -> remove theo giá trị, không phải theo vị trí
                ids.remove(id);
            } else if ("clear".equals(action)) {
                ids.clear();
            }
        }

        String url = request.getContextPath() + "/comparisons";
        if (full) {
            url = url + "?full=1";
        }
        response.sendRedirect(url);
    }

    /** Danh sách id căn đang so sánh, lưu trong session. Chưa có thì tạo mới. */
    @SuppressWarnings("unchecked")
    private static List<Long> getIds(HttpSession session) {
        List<Long> ids = (List<Long>) session.getAttribute(SESSION_KEY);
        if (ids == null) {
            ids = new ArrayList<Long>();
            session.setAttribute(SESSION_KEY, ids);
        }
        return ids;
    }

    private static Long toLong(String text) {
        if (text == null) {
            return null;
        }
        try {
            return Long.valueOf(text.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
