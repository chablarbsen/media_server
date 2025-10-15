FROM python:3.11-slim

LABEL maintainer="KorSub Service"
LABEL description="Korean Subtitle Downloader for Radarr/Sonarr using Cineaste.co.kr"

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY opensubtitles_api.py .
COPY cineaste_scraper.py .
COPY korsub_service_dual.py korsub_service.py

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=7272
ENV LOG_LEVEL=INFO
ENV MEDIA_PATH=/data/media
ENV OPENSUBTITLES_API_KEY=""

# Expose port
EXPOSE 7272

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:7272/health').raise_for_status()"

# Run the service
CMD ["python", "-u", "korsub_service.py"]
