# MOznoDS Frontend

A lightweight React + TypeScript + Vite application for MOznoDS.

## Features

- **Authentication**: Login/Register with JWT (Token) auth.
- **Rooms**: Create and join chat rooms.
- **Real-time Chat**: WebSocket-based messaging with file attachments.
- **Voice/Video Calls**: P2P WebRTC calls with mesh topology.

## Development Setup

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Run Development Server**:
   ```bash
   npm run dev
   ```
   The app will be available at http://localhost:5173.

3. **Environment Variables**:
   Copy `.env.example` to `.env` (if exists) or set:
   ```
   VITE_API_URL=http://localhost:8000
   VITE_WS_URL=ws://localhost:8000
   ```

## Docker

The frontend is included in the main `docker-compose.yml`.
To run the full stack:
```bash
docker-compose up --build
```

## Architecture

- **State Management**: Zustand (`src/store/`)
- **Routing**: React Router v6 (`src/App.tsx`)
- **Styling**: Tailwind CSS
- **API**: Axios + Native WebSocket
