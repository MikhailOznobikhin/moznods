#!/bin/sh
set -e
if [ -d /opt/moznods_flutter_web ]; then
  mkdir -p /app/moznods_flutter/build/web
  # flutter_web_build is a Docker volume mount at this path — do not rm the dir itself (EBUSY).
  find /app/moznods_flutter/build/web -mindepth 1 -delete
  cp -a /opt/moznods_flutter_web/. /app/moznods_flutter/build/web/
  chown -R appuser:appuser /app/moznods_flutter/build/web 2>/dev/null || true
fi
# Publish the fresh Flutter build (and admin assets) to STATIC_ROOT on every start.
runuser -u appuser -g appuser -- python manage.py collectstatic --noinput >/dev/null
exec runuser -u appuser -g appuser -- "$@"
