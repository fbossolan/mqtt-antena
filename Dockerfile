ARG PYTHON_VERSION=3.11

# --- Builder Stage ---
FROM python:${PYTHON_VERSION}-slim AS builder

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies with redundancy for multi-arch environments
# Added python3-dev, libffi-dev, and libssl-dev which are often needed for compiling networking libs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .

# Install dependencies into a specific directory for easy copying
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:${PYTHON_VERSION}-slim

WORKDIR /app

# Copy the pre-installed packages from the builder stage
COPY --from=builder /install /usr/local

ENV PYTHONUNBUFFERED=1

# Copy the rest of the application
COPY . .

# Ensure the app handles data directory creation
# /data is used for Home Assistant, ./data for local dev

EXPOSE 8585

# Using gunicorn with eventlet for SSE support
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "-b", "0.0.0.0:8585", "--chdir", "src", "app:app"]
