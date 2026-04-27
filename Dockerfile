# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build-flutter

WORKDIR /app
COPY moznods_flutter/pubspec.yaml moznods_flutter/pubspec.lock* ./
RUN flutter pub get

COPY moznods_flutter/ ./
RUN dart run build_runner build --delete-conflicting-outputs
RUN flutter build web --release

# Stage 2: Python dependencies
FROM python:3.11-slim AS build-python

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 3: Production Django App
FROM python:3.11-slim AS production

LABEL maintainer="MOznoDS"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash appuser

COPY --from=build-python /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build-python /usr/local/bin /usr/local/bin
COPY --from=build-flutter /app/build/web /app/moznods_flutter/build/web

COPY --chown=appuser:appuser . .

RUN mkdir -p /app/staticfiles /app/media \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["daphne", "-b", "0.0.0.0", "-p", "8000", "config.asgi:application"]