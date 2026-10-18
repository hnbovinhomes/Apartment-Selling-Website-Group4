# Dùng cho Render: build file WAR bằng Maven rồi chạy trên Tomcat 10.1 (Jakarta EE)
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q package -DskipTests

FROM tomcat:10.1-jdk17
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=build /build/target/apartment-web.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
