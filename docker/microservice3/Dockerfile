# Dockerfile for microservice 3
FROM openjdk:11-slim
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser
WORKDIR /app
COPY . /app
RUN gradle build
CMD ["java", "-jar", "app.jar"]