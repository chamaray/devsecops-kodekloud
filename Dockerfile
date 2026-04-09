FROM eclipse-temurin:17-jdk-alpine

WORKDIR /app
EXPOSE 8080

ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

RUN addgroup -S pipeline && adduser -S k8s-pipeline -G pipeline \
    && chown -R k8s-pipeline:pipeline /app

USER k8s-pipeline

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
