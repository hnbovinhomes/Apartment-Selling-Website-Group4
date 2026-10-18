package com.apartment.website.common.controller;

import com.apartment.website.common.util.View;
import com.apartment.website.config.AppContextListener;
import com.apartment.website.property.entity.Property;
import com.apartment.website.property.service.PropertyService;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

/** GET /  ->  views/home.jsp */
public class HomeServlet extends HttpServlet {
    private PropertyService propertyService;

    @Override
    public void init() {
        // lấy service đã lắp sẵn trong AppContextListener
        propertyService = (PropertyService) getServletContext().getAttribute(AppContextListener.PROPERTY_SERVICE);
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        List<Property> featured = propertyService.featured(3);

        // đánh dấu mục menu (header.jsp đọc ${active})
        request.setAttribute("active", "home");
        request.setAttribute("featured", featured);
        View.forward(request, response, "home");
    }
}
