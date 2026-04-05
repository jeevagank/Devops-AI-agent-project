# Dockerfile for microservice 6
FROM node:14-slim
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser
WORKDIR /app
COPY . /app
RUN npm install
CMD ["node", "app.js"]