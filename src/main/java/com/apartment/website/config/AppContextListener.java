package com.apartment.website.config;

import com.apartment.website.appointment.repository.PropertyViewingRepository;
import com.apartment.website.appointment.repository.PropertyViewingRepositoryJdbc;
import com.apartment.website.appointment.service.AppointmentService;
import com.apartment.website.interaction.repository.ReviewRepository;
import com.apartment.website.interaction.repository.ReviewRepositoryJdbc;
import com.apartment.website.interaction.service.ReviewService;
import com.apartment.website.listing.repository.ListingRepository;
import com.apartment.website.listing.repository.ListingRepositoryJdbc;
import com.apartment.website.listing.service.ListingService;
import com.apartment.website.notification.repository.NotificationRepository;
import com.apartment.website.notification.repository.NotificationRepositoryJdbc;
import com.apartment.website.notification.service.NotificationService;
import com.apartment.website.property.repository.PropertyRepository;
import com.apartment.website.property.repository.PropertyRepositoryJdbc;
import com.apartment.website.property.service.PropertyService;
import com.apartment.website.user.repository.UserRepository;
import com.apartment.website.user.repository.UserRepositoryJdbc;
import com.apartment.website.user.service.AuthService;
import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;

/**
 * Chạy 1 lần khi Tomcat khởi động (trước mọi Filter và Servlet): tự tay new các đối tượng và truyền vào nhau
 * qua constructor, rồi cất vào ServletContext để các Servlet / Filter lấy ra dùng.
 */
public class AppContextListener implements ServletContextListener {
    public static final String PROPERTY_SERVICE = "propertyService";
    public static final String APPOINTMENT_SERVICE = "appointmentService";
    public static final String REVIEW_SERVICE = "reviewService";
    public static final String AUTH_SERVICE = "authService";
    public static final String NOTIFICATION_SERVICE = "notificationService";
    public static final String LISTING_SERVICE = "listingService";

    @Override
    public void contextInitialized(ServletContextEvent event) {
        ServletContext context = event.getServletContext();

        // JSP dùng ${ctx} để ghép đường dẫn
        context.setAttribute("ctx", context.getContextPath());

        PropertyRepository propertyRepository = new PropertyRepositoryJdbc();
        PropertyService propertyService = new PropertyService(propertyRepository);
        context.setAttribute(PROPERTY_SERVICE, propertyService);

        UserRepository userRepository = new UserRepositoryJdbc();
        AuthService authService = new AuthService(userRepository);
        context.setAttribute(AUTH_SERVICE, authService);

        NotificationRepository notificationRepository = new NotificationRepositoryJdbc();
        NotificationService notificationService = new NotificationService(notificationRepository);
        context.setAttribute(NOTIFICATION_SERVICE, notificationService);

        // AppointmentService cần NotificationService để báo cho chủ căn hộ / khách khi lịch hẹn đổi trạng thái
        PropertyViewingRepository viewingRepository = new PropertyViewingRepositoryJdbc();
        AppointmentService appointmentService = new AppointmentService(viewingRepository, notificationService);
        context.setAttribute(APPOINTMENT_SERVICE, appointmentService);

        ReviewRepository reviewRepository = new ReviewRepositoryJdbc();
        ReviewService reviewService = new ReviewService(reviewRepository);
        context.setAttribute(REVIEW_SERVICE, reviewService);

        ListingRepository listingRepository = new ListingRepositoryJdbc();
        ListingService listingService = new ListingService(listingRepository);
        context.setAttribute(LISTING_SERVICE, listingService);

        // Thêm tính năng mới: new XxxRepository -> new XxxService(repo) -> context.setAttribute(...)
        context.log("Apartment web khoi dong (PostgreSQL)");
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        Database.shutdown();
    }
}
