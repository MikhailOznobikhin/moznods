# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.13.0 AS build-env

WORKDIR /app
COPY moznods_flutter/pubspec.yaml moznods_flutter/pubspec.lock* ./
RUN flutter pub get

COPY moznods_flutter/ ./
# Генерируем .g.dart файлы для моделей
RUN flutter pub run build_runner build --delete-conflicting-outputs

# Собираем Web-версию
RUN flutter build web --release

# Stage 2: Django App
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements/requirements.txt requirements/requirements.txt
RUN pip install --no-cache-dir -r requirements/requirements.txt

# Copy project
COPY . .

# Copy built Flutter Web files from Stage 1
COPY --from=build-env /app/build/web /app/moznods_flutter/build/web

# Collect static files (now including Flutter build)
RUN python manage.py collectstatic --noinput

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "config.wsgi:application"]
