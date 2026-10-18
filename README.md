# Apartment Web - Servlet / JSP (Jakarta EE 10) trên Tomcat 10.1

Yêu cầu: JDK 17+, Maven, Apache Tomcat 10.1.x (KHÔNG dùng Tomcat 9 vì code dùng jakarta.*).

1. IntelliJ: File > Open thư mục này (nhận là Maven project, packaging war).
2. Run > Edit Configurations > + Tomcat Server > Local (bản Ultimate) hoặc plugin "Smart Tomcat" (bản Community).
   Deployment: apartment-web:war exploded, Application context: /
3. Mở http://localhost:8080  (mặc định data.mode=mock, chưa cần database).
4. Dùng PostgreSQL: chạy database/01_..._pg.sql rồi 02_..._pg.sql, sửa src/main/resources/app.properties
   (data.mode=postgres, db.url, db.user, db.password) hoặc đặt biến môi trường DATA_MODE, DB_URL, DB_USER, DB_PASSWORD.
