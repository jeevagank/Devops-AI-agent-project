# Dockerfile for microservice 5
FROM python:3.9-slim
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser
WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt
CMD ["python", "app.py"]