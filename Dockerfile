ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim

WORKDIR /app

COPY requirements.txt .

# Install build dependencies, install requirements, and remove build dependencies in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove gcc libc-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY . .
# No need to mkdir -p data here; the app handles it,
# and for HA, /data is mounted from the host.

EXPOSE 8585

# Using gunicorn with eventlet for SSE support
# Change dir to src so it can find app:app and relative templates/static
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "-b", "0.0.0.0:8585", "--chdir", "src", "app:app"]
