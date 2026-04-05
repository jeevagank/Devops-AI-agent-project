# Create a multi-stage Dockerfile for each microservice
FROM python:3.9-slim as base

# Install dependencies
RUN pip install -r requirements.txt

# Copy application code
COPY . /app

# Expose port 80
EXPOSE 80

# Run command
CMD ["python", "app.py"]
