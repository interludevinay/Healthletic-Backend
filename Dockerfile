# Base image
FROM python:3.12-slim

# Set work directory
WORKDIR /app

# Copy requirements and install
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app files
COPY app/ .

# Expose port
EXPOSE 5000

# Run app
CMD ["python", "app.py"]
