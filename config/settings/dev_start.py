"""
Временные настройки для первого запуска
CSRF отключен для админки
"""
from .low_memory import *

# Отключаем CSRF защиту ВРЕМЕННО!
MIDDLEWARE = [m for m in MIDDLEWARE if 'CsrfViewMiddleware' not in m]

# Максимально открытые настройки
CSRF_TRUSTED_ORIGINS = ['http://193.124.117.231', 'https://193.124.117.231', 'http://localhost']
CSRF_COOKIE_SECURE = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_HTTPONLY = False

DEBUG = True  # Включим для подробных ошибок

# Разрешаем всё для теста
ALLOWED_HOSTS = ['*']
CORS_ALLOW_ALL_ORIGINS = True
