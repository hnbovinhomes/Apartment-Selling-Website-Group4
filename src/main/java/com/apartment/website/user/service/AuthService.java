package com.apartment.website.user.service;

import com.apartment.website.common.exception.AuthException;
import com.apartment.website.common.util.PasswordHasher;
import com.apartment.website.user.dto.RegisterRequest;
import com.apartment.website.user.entity.Customer;
import com.apartment.website.user.entity.Owner;
import com.apartment.website.user.entity.User;
import com.apartment.website.user.repository.UserRepository;

/** Quy tắc đăng nhập / đăng ký. login() / logout() trong diagram nằm ở đây và ở AuthServlet. */
public class AuthService {
    private static final String PHONE_PATTERN = "^0\\d{9}$";
    private static final String CCCD_PATTERN = "^(\\d{9}|\\d{12})$";
    private static final String EMAIL_PATTERN = "^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+$";
    // giới hạn theo độ dài cột trong bảng users
    private static final int MAX_FULL_NAME = 150;
    private static final int MAX_EMAIL = 150;
    private static final int MIN_PASSWORD = 8;
    // BCrypt chỉ dùng tối đa 72 byte đầu của mật khẩu
    private static final int MAX_PASSWORD = 72;

    private final UserRepository repository;

    public AuthService(UserRepository repository) {
        this.repository = repository;
    }

    /** Đăng nhập bằng số điện thoại hoặc email. Đúng thì trả về User (không kèm mật khẩu), sai thì ném AuthException. */
    public User login(String phoneOrEmail, String password) {
        String identifier = trimText(phoneOrEmail);
        if (identifier.isEmpty() || password == null || password.isEmpty()) {
            throw new AuthException("Vui lòng nhập số điện thoại (hoặc email) và mật khẩu.");
        }

        User user = repository.findByPhoneOrEmail(identifier);
        // cột users.password_hash lưu chuỗi đã băm BCrypt -> băm mật khẩu vừa nhập rồi so với chuỗi đó.
        // Không nói rõ sai SĐT hay sai mật khẩu để người lạ không dò được tài khoản
        if (user == null || !PasswordHasher.checkPassword(password, user.getPasswordHash())) {
            throw new AuthException("Số điện thoại/email hoặc mật khẩu không đúng.");
        }
        if (!user.isActive()) {
            String message = "Tài khoản đã bị khóa.";
            if (user.getBlockedReason() != null) {
                message = message + " Lý do: " + user.getBlockedReason();
            }
            throw new AuthException(message);
        }

        repository.updateLastLogin(user.getUserId());
        // không giữ mật khẩu trong session
        user.setPasswordHash(null);
        return user;
    }

    /** Đăng ký tài khoản Khách hàng hoặc Chủ căn hộ. Thành công thì trả về User vừa tạo (đăng nhập luôn). */
    public User register(RegisterRequest request) {
        // 1. Chuẩn hóa dữ liệu
        String role = trimText(request.getRole());
        String fullName = trimText(request.getFullName()).replaceAll("\\s+", " ");
        // "0901 234.567" -> "0901234567"
        String phone = trimText(request.getPhone()).replaceAll("[\\s.\\-]", "");
        String cccd = trimText(request.getCccd());
        String email = trimText(request.getEmail()).toLowerCase();
        String password = request.getPassword();
        if (password == null) {
            password = "";
        }

        // 2. Kiểm tra từng ô
        if (!User.ROLE_CUSTOMER.equals(role) && !User.ROLE_OWNER.equals(role)) {
            throw new AuthException("Vui lòng chọn vai trò Khách hàng hoặc Chủ căn hộ.");
        }
        if (fullName.isEmpty()) {
            throw new AuthException("Vui lòng nhập họ và tên.");
        }
        if (fullName.length() > MAX_FULL_NAME) {
            throw new AuthException("Họ và tên tối đa " + MAX_FULL_NAME + " ký tự.");
        }
        if (!phone.matches(PHONE_PATTERN)) {
            throw new AuthException("Số điện thoại phải gồm 10 chữ số và bắt đầu bằng 0.");
        }
        if (!cccd.isEmpty() && !cccd.matches(CCCD_PATTERN)) {
            throw new AuthException("Số CCCD / CMND phải gồm 9 hoặc 12 chữ số.");
        }
        if (email.length() > MAX_EMAIL || !email.matches(EMAIL_PATTERN)) {
            throw new AuthException("Email không hợp lệ.");
        }
        if (password.length() < MIN_PASSWORD || password.length() > MAX_PASSWORD) {
            throw new AuthException("Mật khẩu phải từ " + MIN_PASSWORD + " đến " + MAX_PASSWORD + " ký tự.");
        }
        if (!password.matches(".*[A-Za-z].*") || !password.matches(".*\\d.*")) {
            throw new AuthException("Mật khẩu phải có cả chữ và số.");
        }
        if (!password.equals(request.getConfirmPassword())) {
            throw new AuthException("Xác nhận mật khẩu không khớp.");
        }

        // 3. Không cho trùng (DB cũng có UNIQUE, nhưng kiểm tra trước để báo lỗi dễ hiểu)
        if (repository.existsByPhone(phone)) {
            throw new AuthException("Số điện thoại này đã được đăng ký.");
        }
        if (repository.existsByEmail(email)) {
            throw new AuthException("Email này đã được đăng ký.");
        }
        if (!cccd.isEmpty() && repository.existsByCccd(cccd)) {
            throw new AuthException("Số CCCD / CMND này đã được đăng ký.");
        }

        // 4. Tạo object rồi lưu xuống DB
        User user;
        if (User.ROLE_OWNER.equals(role)) {
            user = new Owner();
        } else {
            user = new Customer();
        }
        user.setUsername(phone);
        user.setFullName(fullName);
        user.setPhone(phone);
        if (cccd.isEmpty()) {
            user.setCccd(null);
        } else {
            user.setCccd(cccd);
        }
        user.setEmail(email);
        // băm mật khẩu bằng BCrypt rồi mới lưu vào cột users.password_hash (không lưu mật khẩu gốc)
        user.setPasswordHash(PasswordHasher.hashPassword(password));
        user.setActive(true);

        long userId = repository.create(user);
        user.setUserId(userId);
        user.setPasswordHash(null);
        return user;
    }

    private static String trimText(String text) {
        if (text == null) {
            return "";
        }
        return text.trim();
    }
}
