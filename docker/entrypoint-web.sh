#!/bin/sh
set -e
if [ -d /opt/moznods_flutter_web ]; then
  rm -rf /app/moznods_flutter/build/web
  mkdir -p /app/moznods_flutter/build/web
  cp -a /opt/moznods_flutter_web/. /app/moznods_flutter/build/web/
  chown -R appuser:appuser /app/moznods_flutter/build/web 2>/dev/null || true
fi
exec runuser -u appuser -g appuser -- "$@"
