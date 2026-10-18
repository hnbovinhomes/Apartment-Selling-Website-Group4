package com.apartment.website.common.util;

import org.mindrot.jbcrypt.BCrypt;

/**
 * Băm và kiểm tra mật khẩu bằng thuật toán BCrypt (thư viện jBCrypt).
 * Chuỗi băm có dạng $2a$10$<22 ký tự salt><31 ký tự hash>, dài 60 ký tự,
 * salt nằm sẵn trong chuỗi nên không cần thêm cột lưu salt.
 */
public class PasswordHasher {
    // số vòng băm = 2^10; càng lớn càng chậm, càng khó dò mật khẩu
    private static final int LOG_ROUNDS = 10;

    public static String hashPassword(String plainPassword) {
        String salt = BCrypt.gensalt(LOG_ROUNDS);
        return BCrypt.hashpw(plainPassword, salt);
    }

    public static boolean checkPassword(String plainPassword, String hashedPassword) {
        if (plainPassword == null) {
            return false;
        }
        // dữ liệu cũ chưa băm (vd "Matkhau123") thì không phải chuỗi BCrypt -> coi như sai mật khẩu
        if (hashedPassword == null || !hashedPassword.startsWith("$2")) {
            return false;
        }
        try {
            return BCrypt.checkpw(plainPassword, hashedPassword);
        } catch (IllegalArgumentException e) {
            // chuỗi trong DB hỏng / sai định dạng
            return false;
        }
    }
}
