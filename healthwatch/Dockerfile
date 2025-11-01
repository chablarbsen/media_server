FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY healthwatch.py .
COPY templates/ templates/
COPY static/ static/

# Create data directory for state persistence
RUN mkdir -p /data

# Note: Container runs as root to access Docker socket
# Docker socket is mounted read-only for security

# Expose web dashboard port
EXPOSE 8888

# Run the health monitor
CMD ["python", "-u", "healthwatch.py"]
