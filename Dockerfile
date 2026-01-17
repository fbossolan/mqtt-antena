FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY . .
RUN mkdir -p data

# Create a volume for the database persistence if needed, 
# but for now we keep it simple in the container or mounted via execution
# EXPOSE the requested port
EXPOSE 8585

# Using gunicorn with eventlet for SSE support
# Change dir to src so it can find app:app and relative templates/static
CMD ["gunicorn", "--worker-class", "eventlet", "-w", "1", "-b", "0.0.0.0:8585", "--chdir", "src", "app:app"]
