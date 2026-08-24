Markdown

````
# 🛡️ Guardian AI

> **Guardian AI** is an AI-powered personal safety mobile application that combines real-time GPS tracking, intelligent route planning, voice distress detection, motion sensing, and emergency SOS into one unified safety platform.

---

## ✨ Features

### 🚀 Smart Safe Journey
- Real-time GPS tracking
- Safer, Fastest & Balanced route planning
- Live ETA and distance monitoring
- Route deviation detection
- Safe arrival confirmation

### 🎙️ Voice Distress Detection
- Continuous voice monitoring in Guardian Mode
- Detects emergency keywords like **Help**, **Danger**, and **Emergency**
- 20-second safety confirmation before SOS
- Hands-free emergency activation

### 📳 Motion & Fall Detection
- Accelerometer-based motion anomaly detection
- Gyroscope-assisted fall validation
- False-positive reduction using multi-signal verification
- Emergency confirmation dialog

### 🛡️ Guardian Mode
- Background safety watchdog
- GPS monitoring
- Motion monitoring
- Voice monitoring
- Route watchdog
- Risk assessment engine

### 🚨 Intelligent SOS
- One-tap emergency SOS
- Automatic SOS based on verified risk score
- Live location sharing
- Trusted contact notifications
- Emergency countdown cancellation

### 👥 Trusted Contacts
- Add/Edit/Delete emergency contacts
- Native phone contact picker
- Relationship & priority management
- Live location sharing preferences

### 🤖 AI Safety Intelligence
- Risk score calculation
- Crime-aware route evaluation
- Weather-aware safety insights
- Journey anomaly detection

---

## 📱 Screens

- Splash Screen
- Login & Google Authentication
- Home Dashboard
- Map & Route Planning
- Journey Confirmation
- Live Journey
- Guardian Mode
- Trusted Contacts
- Activity Timeline
- Profile & Settings
- Emergency SOS

---

## 🏗️ Tech Stack

### Frontend
- Flutter
- Dart
- Riverpod
- Material 3
- Google Maps Flutter

### Backend
- FastAPI
- PostgreSQL
- Redis
- SQLAlchemy
- JWT Authentication

### AI & Services
- Google Gemini
- Google Directions API
- Geolocator
- Speech-to-Text
- Sensors Plus
- Firebase Cloud Messaging
- Twilio

---

## 📂 Project Structure

```text
guardian-ai/
├── backend/
│   ├── app/
│   ├── alembic/
│   ├── Dockerfile
│   └── requirements.txt
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

## ⚙️ Getting Started

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/guardian-ai.git
cd guardian-ai
```

### 2. Backend Setup

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Backend runs at:

```text
http://localhost:8000
```

### 3. Flutter Setup

```bash
flutter pub get
```

Run on Android:

```bash
flutter run --dart-define=API_HOST=192.168.1.6
```

For production:

```bash
flutter build apk --release \
--dart-define=API_BASE_URL=https://api.yourdomain.com/api/v1
```

---

## 🔐 Environment Variables

Create a `.env` inside `backend/`:

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

## 🧠 Safety Pipeline

```text
GPS + Motion + Voice + Route + Weather
                 │
                 ▼
        AI Risk Assessment
                 │
                 ▼
     Are You In Danger?
       (20 sec countdown)
        │             │
        ▼             ▼
   I'm Safe      Send SOS
                      │
                      ▼
        Trusted Contacts + Live Location
```

---

## 🎯 Roadmap

- [x] JWT Authentication
- [x] Google Authentication
- [x] Real GPS Tracking
- [x] Smart Route Planning
- [x] Guardian Mode
- [x] Motion Detection
- [x] Voice Distress Detection
- [x] Trusted Contacts
- [x] Intelligent SOS
- [ ] Offline Emergency Sync
- [ ] Wear OS Companion
- [ ] AI Safety Insights

---

## 👨‍💻 Developed By

**Roshan**  
CSE Student • Flutter • FastAPI • AI Systems

---

## 📄 License

This project is licensed under the **MIT License**.
````
