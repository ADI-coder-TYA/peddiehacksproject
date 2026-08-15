# MedAccess AI
> **Autonomous Clinical Triage · Medical Claim Verification · Emergency Copay Engine**

[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-blue.svg)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue.svg)](https://www.typescriptlang.org)
[![TensorFlow.js](https://img.shields.io/badge/TensorFlow.js-DeepRank-orange.svg)](https://js.tensorflow.org)
[![ONNX](https://img.shields.io/badge/ONNX-Qwen2.5--0.5B-purple.svg)](https://huggingface.co/onnx-community)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🏥 What Is MedAccess AI?

**MedAccess AI** is a full-stack autonomous healthcare access and clinical welfare platform designed to eliminate financial bottlenecks during acute medical emergencies. When a patient or student faces an emergency, delays in insurance adjudication or out-of-pocket copay obligations can cause severe health deterioration.

MedAccess AI combines:
- 🧠 **Local zero-cost ML models** (TensorFlow.js DeepRank, LSTM, Autoencoder)
- 📑 **Layout-aware invoice OCR** (Poppler + Tesseract)
- 🛡️ **Perceptual fraud detection** (SHA-256 + autoencoder anomaly scoring)
- 💬 **Real-time Psychological First Aid** (local Qwen2.5-0.5B ONNX)
- 💳 **Instant multi-rail copay disbursements** (RazorpayX UPI / Stripe ACH)

...to deliver verified financial relief in under 2 minutes for critical cases.

---

## ⚡ End-to-End Pipeline

```
[Patient submits Hospital PDF or SOS Message]
                     │
                     ▼
[Local Qwen2.5-0.5B PFA Counselor] ──► Instant empathetic reply + crisis hotlines
                     │
                     ▼
[IntakeWorker (BullMQ clinical-intake-queue)]
   ├── Poppler-Utils Layout Parser  ──► Extracts exact bill total (₹4,305 / $500)
   ├── Fraud Sentinel Engine        ──► SHA-256 duplicate hash + velocity checks
   └── DeepRank ESI Classifier      ──► Computes Crisis Severity Index (CSI)
                     │
                     ▼
[Admin Clinical War Room Dashboard]
   ├── One-tap RazorpayX UPI / Stripe Payout
   └── HIPAA Audit PDF with SHA-256 tamper-evident hash
```

---

## 🩺 ESI Triage Protocol

| ESI Level | Clinical Description | CSI Score | Coverage | SLA |
|---|---|---|---|---|
| **ESI 1 – Critical** | Resuscitation, severe trauma, acute bleeding | `≥ 0.85` | **100%** (Up to ₹80,000 / $2,500) | `< 2 min` |
| **ESI 2 – Emergent** | Severe pain, critical medication shortage | `0.60–0.85` | **80%** (Up to ₹40,000 / $1,500) | `< 10 min` |
| **ESI 3 – Urgent** | Moderate distress, acute fracture, imaging | `0.35–0.60` | **50%** (Up to ₹20,000 / $800) | `< 30 min` |
| **Routine** | Scheduled labs, standard outpatient | `< 0.35` | **30%** (Up to ₹5,000 / $200) | `< 2 hrs` |

---

## 🚀 Key Modules & Capabilities

### 1. 🧠 24/7 PFA Counselor (Local ONNX)
- Runs `onnx-community/Qwen2.5-0.5B-Instruct` on CPU — **zero API cost, offline-capable**
- Falls back to a Rogerian PFA rule engine when local model is unavailable
- Auto-detects self-harm keywords and routes to crisis hotlines:
  - 📞 **Tele-MANAS (India):** `14416` / `1800-891-4416`
  - 📞 **988 Crisis Lifeline (US):** `988`
  - 📞 **Vandrevala Foundation:** `+91 9999 666 555`

### 2. 📑 Layout-Preserving Invoice OCR
- `pdftotext -layout` (Poppler) preserves right-aligned invoice columns
- Tesseract.js fallback for scanned image receipts (PNG, JPG, WebP, TIFF)
- High-precision regex extracts "TOTAL DUE", "GRAND TOTAL", "NET PAYABLE" anchors

### 3. 🛡️ Fraud Sentinel
- **SHA-256 image hash** deduplicates recycled/reused receipts across all claims
- **7-day velocity check** flags repeat claimants with configurable threshold
- **Autoencoder anomaly model** detects statistically unusual claim feature vectors
- Life-safety critical claims receive reduced fraud sensitivity

### 4. 💳 Multi-Rail Copay Disbursement
- **INR:** RazorpayX UPI (instant) or IMPS bank transfer
- **USD:** Stripe Instant Payouts / ACH
- **Sandbox:** Cryptographic voucher codes (`EDU-GRANT-XXXXXX`) when APIs are offline

### 5. 📑 HIPAA Audit PDF Engine
- PDFKit-generated tamper-evident governance reports
- SHA-256 integrity checksums across all adjudicated records
- For institutional deans, hospital boards, and state auditors

---

## 🛠️ Tech Stack

| Layer | Technologies |
|---|---|
| **Mobile / Web Client** | Flutter 3.29+ (Dart), Provider (MVVM), Google Fonts, FL Chart, Socket.io Client |
| **Backend API** | Node.js 18+, Express 5, TypeScript 5, BullMQ, Redis |
| **Database & Auth** | Supabase (PostgreSQL), Row-Level Security, JWT |
| **Machine Learning** | TensorFlow.js 4.x (DeepRank, LSTM, Autoencoder), Xenova Transformers (Qwen2.5 ONNX) |
| **Document Parsing** | Poppler (`pdftotext -layout`), Tesseract.js 7 |
| **Payment Rails** | RazorpayX Payouts (UPI/IMPS), Stripe Instant Payouts |
| **Notifications** | Nodemailer, Twilio SMS, Resend |
| **PDF Reporting** | PDFKit |
| **Containerization** | Docker, docker-compose |

---

## 📁 Repository Structure

```
medaccess-ai/
├── intellidesk_app/          # Flutter mobile/web client
│   └── lib/
│       ├── models/           # Domain entities (Claim, Message, HealthFund)
│       ├── services/         # API + Socket.io + offline sync
│       ├── providers/        # MVVM ViewModels (Provider)
│       ├── screens/          # Patient & Admin UI screens
│       └── theme/            # Design system & ESI color tokens
├── intellidesk_backend/      # Node.js/Express backend
│   └── src/
│       ├── ml/               # TF.js model definitions (DeepRank, LSTM, Autoencoder)
│       ├── services/         # Business logic (OCR, fraud, payout, PFA, PDF)
│       ├── routes/           # REST API route handlers
│       ├── workers/          # BullMQ background job workers
│       ├── middleware/        # Auth, RBAC, tenant scoping
│       └── controllers/      # Request/response controllers
├── supabase_core_schema.sql  # PostgreSQL schema with RLS
├── supabase_setup.sql        # Supabase project bootstrap
└── ARCHITECTURE.md           # Detailed system design doc
```

---

## 🏁 Quick Start

### Prerequisites
- **Node.js** v18+ or v20 LTS
- **Flutter SDK** v3.29+
- **Redis Server** (for BullMQ workers)
- **Supabase** project (or local Supabase CLI)

### 1. Clone & Configure Backend
```bash
cd intellidesk_backend
cp .env.example .env          # Fill in SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, etc.
npm install
npm run train:ml              # Generate DeepRank / LSTM / Autoencoder weights
npm run dev                   # Start Express + BullMQ workers on :3000
```

### 2. Seed Database
```bash
npm run seed:all              # Seeds policies, health funds, audit logs
```

### 3. Flutter Client
```bash
cd intellidesk_app
flutter pub get
flutter run                   # Runs on connected device/emulator/Chrome
```

### 4. Docker (Optional)
```bash
docker-compose up --build     # Backend + Redis in containers
```

---

## 👥 Demo Credentials

| Role | Email | Password | Access |
|---|---|---|---|
| **Patient / Student** | `alex.rivera@campushealth.edu` | `demo123` | Submit claims, PFA chat, track status |
| **Chief Medical Officer** | `dr.chen@medaccess.ai` | `admin123` | War Room, ESI overrides, payout disbursement |

---

## 🔒 Security & Compliance

- **RBAC** enforced on all endpoints (`STUDENT` / `ADMIN` / `AUDITOR`)
- **Row-Level Security (RLS)** on all Supabase tables — data isolation per `institution_id`
- **JWT authentication** via Supabase Auth with role claims
- **Audit logs** capture every ESI override, fraud flag, and disbursement with cryptographic timestamps
- **SHA-256 tamper-evident** hashing on audit PDFs and receipt images

---

## 📚 Documentation

| Document | Description |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | System topology, DB schema, API spec, worker design |
| [docs/ML_REFERENCE.md](./docs/ML_REFERENCE.md) | DeepRank, LSTM, Autoencoder, PFA counselor deep-dive |
| [docs/BACKEND_REFERENCE.md](./docs/BACKEND_REFERENCE.md) | API routes, services, middleware, workers |
| [docs/FRONTEND_REFERENCE.md](./docs/FRONTEND_REFERENCE.md) | Flutter MVVM, screens, providers, theme |
| [docs/USER_GUIDE.md](./docs/USER_GUIDE.md) | Patient & Admin real-world usage workflows |

---

## 📄 License
MedAccess AI is licensed under the [MIT License](./LICENSE).
