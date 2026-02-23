# План реализации Frontend для MOznoDS

Этот план описывает создание легковесного Frontend-приложения (SPA) для взаимодействия с backend MOznoDS.

## 1. Технологический стек

*   **Сборщик**: Vite
*   **Фреймворк**: React + TypeScript
*   **Стилизация**: Tailwind CSS (быстрая верстка)
*   **Роутинг**: React Router v6
*   **Состояние**: Zustand (простое управление глобальным стейтом: auth, rooms)
*   **API Клиент**: Axios (HTTP)
*   **Real-time**: Native WebSocket API (для чата и сигнализации)
*   **WebRTC**: Native WebRTC API (RTCPeerConnection) для P2P звонков

## 2. Структура проекта

Предлагается создать директорию `frontend/` в корне репозитория.

```
frontend/
├── src/
│   ├── api/              # Axios instance, endpoints
│   ├── components/       # UI компоненты (Button, Input, Layout)
│   ├── hooks/            # Custom hooks (useAuth, useChat, useWebRTC)
│   ├── pages/            # Страницы (Login, Register, Dashboard, Room)
│   ├── store/            # Zustand stores (useAuthStore, useRoomStore)
│   ├── types/            # TypeScript интерфейсы
│   └── utils/            # Хелперы (форматирование даты, работа с файлами)
├── .env                  # API URL конфиг
└── package.json
```

## 3. Основные экраны и функциональность

### 3.1. Аутентификация
*   **Страницы**: `/login`, `/register`
*   **Функции**:
    *   Вход по username/password.
    *   Регистрация с `invite_code` (получение токена).
    *   Сохранение токена в `localStorage`.
    *   Редирект на `/` после входа.

### 3.2. Главная (Dashboard) / Layout
*   **Sidebar**:
    *   Список комнат (получение через `GET /api/rooms/`).
    *   Кнопка "Создать комнату" (модальное окно).
    *   Кнопка "Выход".
    *   Отображение текущего пользователя.
*   **Main Area**:
    *   Плейсхолдер "Выберите комнату" или интерфейс выбранной комнаты.

### 3.3. Комната (Room View)
*   **Роут**: `/room/:roomId`
*   **Компоненты**:
    *   **ChatArea**: Список сообщений, инпут, кнопка отправки, загрузка файлов.
    *   **CallArea**: Панель управления звонком (Join/Leave), список участников с индикаторами голоса/видео.

## 4. Реализация Real-time (WebSocket & WebRTC)

### 4.1. Чат (WebSocket)
*   URL: `ws://localhost:8000/ws/room/:roomId/?token=...`
*   События: `chat_message` (получение), отправка JSON.
*   Вложения: Сначала загрузка файла через `POST /api/files/upload/`, затем отправка ID файла в сокет.

### 4.2. Звонки (WebRTC Mesh)
*   URL: `ws://localhost:8000/ws/call/:roomId/?token=...`
*   **Логика (Mesh Topology)**:
    *   При входе (`join_room`) получаем список участников.
    *   Инициируем `RTCPeerConnection` с каждым участником.
    *   Обмен `offer`/`answer` и `ice_candidate` через WebSocket.
    *   Отображение `<audio>` элементов для каждого удаленного потока.

## 6. Docker Интеграция

Для запуска приложения целиком через Docker, необходимо добавить конфигурацию для Frontend.

*   **Dockerfile (frontend)**:
    *   Development режим: использование Node.js образа, установка зависимостей и запуск `vite dev` (с пробросом портов).
    *   Production режим (на будущее): Multi-stage build (Node build -> Nginx alpine).
*   **Docker Compose**:
    *   Добавление сервиса `frontend`.
    *   Проброс порта `5173` (Vite default).
    *   Настройка volumes для hot-reload (`./frontend:/app`).

## 7. Пошаговый план разработки

1.  **Инициализация**:
    *   Создать проект Vite.
    *   Настроить Tailwind.
    *   Настроить Axios и базовый API клиент.
    *   **Docker**: Добавить `Dockerfile` и обновить `docker-compose.yml`.
2.  **Auth & Routing**:
    *   Реализовать Login/Register.
    *   Настроить PrivateRoute (защита от неавторизованного доступа).
3.  **Rooms & Chat**:
    *   Sidebar со списком комнат.
    *   Создание комнат.
    *   **Ограничение**: Добавить лимит на количество комнат для предотвращения спама (TODO).
    *   Чат интерфейс (верстка).
    *   Подключение WebSocket чата.
4.  **Files**:
    *   Реализовать загрузку файлов и отображение в чате.
5.  **Voice Calls (MVP)**:
    *   Подключение Signaling WebSocket.
    *   Реализация WebRTC логики (простой аудио-звонок).

## 8. Запуск и Деплой

*   **Запуск через Docker**: `docker-compose up --build`.
    *   Frontend будет доступен по адресу `http://localhost:5173`.
    *   Backend API по адресу `http://localhost:8000`.
*   Proxy: Настроить proxy в `vite.config.ts` для API запросов к Django, чтобы избежать CORS проблем (опционально, т.к. CORS включен).
