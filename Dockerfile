# Use JDK 11 runtime
FROM eclipse-temurin:11-jre-alpine

# Expose port
EXPOSE 8080

# Copy jar from Maven build
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

# Run the jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
