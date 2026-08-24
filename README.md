
# 🛡️ Guardian AI

<div align="center">

### AI-Powered Personal Safety & Intelligent Emergency Response Platform

*Protect • Detect • Assess • Respond*

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi)
![Postgres](https://img.shields.io/badge/PostgreSQL-16-336791?style=for-the-badge&logo=postgresql)
![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-7F52FF?style=for-the-badge)
![Material3](https://img.shields.io/badge/Material%203-Premium-8B5CF6?style=for-the-badge)

</div>

---

## 🌟 Overview

Guardian AI is an **AI-first personal safety application** that combines real-time GPS tracking, intelligent route planning, motion sensing, voice distress detection, and emergency SOS into one unified safety ecosystem.

Instead of reacting to a single trigger, Guardian AI evaluates **multiple safety signals** before making emergency decisions.

---

## ✨ Core Features

| Feature | Description |
|---------|-------------|
| 🛰️ **Live GPS Tracking** | Real-time location, speed & ETA monitoring |
| 🗺️ **Smart Route Planning** | Safer, Fastest & Balanced routes |
| 🎙️ **Voice Distress AI** | Detects emergency keywords hands-free |
| 📳 **Motion Detection** | Accelerometer + Gyroscope anomaly detection |
| 🛡️ **Guardian Mode** | Background intelligent safety watchdog |
| 🚨 **Smart SOS** | 20-second confirmation before emergency dispatch |
| 👥 **Trusted Contacts** | Live location sharing with emergency contacts |
| 🌦️ **Risk Intelligence** | Weather, route & environmental safety analysis |

---

# 🧠 AI Safety Pipeline

```text
      GPS Tracking
           │
           ▼
   Route Watchdog
           │
           ▼
 Voice Distress AI
           │
           ▼
 Motion Sensors
           │
           ▼
   AI Risk Engine
           │
           ▼
  Are You In Danger?
     (20 Seconds)
      │        │
      ▼        ▼
 I'm Safe   Send SOS
                │
                ▼
 Trusted Contacts + Live Location
```

---

# 📱 Application Flow

```text
Splash
   │
   ▼
Authentication
(Login / Google)
   │
   ▼
Home Dashboard
   │
   ▼
Safe Route Planning
   │
   ▼
Journey Confirmation
   │
   ▼
Live Journey
   │
   ▼
Guardian Monitoring
   │
   ▼
Emergency SOS
```

---

# 🏗️ Architecture

```text
             Flutter Mobile App
                    │
        Riverpod + Material 3
                    │
          REST API (HTTPS)
                    │
              FastAPI Backend
        ┌───────────┼───────────┐
        │           │           │
 PostgreSQL      Redis      Gemini AI
        │           │           │
        └──── Google Maps ──────┘
                    │
              Twilio + FCM
```

---

# 📂 Project Structure

```text
guardian-ai/
│
├── backend/
│   ├── app/
│   ├── alembic/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── docker-compose.yml
│
├── lib/
│   ├── core/
│   ├── data/
│   ├── domain/
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── map/
│   │   ├── guardian/
│   │   ├── journey/
│   │   ├── profile/
│   │   └── activity/
│   └── main.dart
│
└── README.md
```

---

# 🚀 Getting Started

## 1️⃣ Clone Repository

```bash
git clone https://github.com/your-username/guardian-ai.git
cd guardian-ai
```

## 2️⃣ Backend Setup

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Backend runs on:

```text
http://localhost:8000
```

---

## 3️⃣ Flutter Setup

```bash
flutter pub get
```

Run on Android:

```bash
flutter run --dart-define=API_HOST=192.168.1.6
```

Production:

```bash
flutter build apk --release \
--dart-define=API_BASE_URL=https://api.guardianai.com/api/v1
```

---

# 🔐 Environment Variables

Create `backend/.env`

```env
DATABASE_URL=
REDIS_URL=

JWT_SECRET=

GOOGLE_CLIENT_ID=
GOOGLE_MAPS_API_KEY=
GEMINI_API_KEY=

WEATHER_API_KEY=

TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
```

---

# 🛠️ Technology Stack

| Category | Technologies |
|----------|--------------|
| **Frontend** | Flutter, Dart, Riverpod, Material 3 |
| **Backend** | FastAPI, SQLAlchemy, JWT |
| **Database** | PostgreSQL, Redis |
| **AI** | Google Gemini |
| **Maps** | Google Maps & Directions API |
| **Sensors** | Geolocator, Sensors Plus, Speech-to-Text |
| **Notifications** | Firebase Cloud Messaging |
| **Emergency** | Twilio SMS |

---

# 🎯 Roadmap

- [x] JWT Authentication
- [x] Google Authentication
- [x] Live GPS Tracking
- [x] Smart Route Planning
- [x] Guardian Mode
- [x] Motion Detection
- [x] Voice Distress Detection
- [x] Trusted Contacts
- [x] Intelligent SOS
- [ ] Offline Emergency Sync
- [ ] Wear OS Companion
- [ ] AI Predictive Safety Insights

---

# 👨‍💻 Developer

<div align="center">

## Roshan

**Computer Science Engineering • Flutter • FastAPI • AI Systems**

*Building intelligent technology for real-world safety.*

</div>

---

<div align="center">

### ⭐ If you like this project, consider giving it a Star!

**Guardian AI © 2026**

</div>
