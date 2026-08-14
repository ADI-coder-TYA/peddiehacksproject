# MedAccess AI

**Autonomous Clinical Triage, Medical Claim Verification & Emergency Copay Engine**

---

## What It Does

MedAccess AI bridges the gap between acute patient distress and immediate financial relief.  
It combines zero-cost, offline clinical triage ML models with layout-aware medical invoice OCR and instant micro-grant disbursement rails.

### Key Capabilities
- 🩺 **Clinical Triage** — ESI Level 1–3 severity scoring via local TF.js DeepRank model
- 📑 **Invoice OCR** — Poppler + Tesseract layout-aware hospital bill parsing
- 🛡️ **Fraud Sentinel** — SHA-256 duplicate receipt detection + velocity checks
- 💳 **Copay Engine** — Instant grant calculation & disbursement tracking
- 🧠 **PFA Counselor** — 24/7 Psychological First Aid via local Qwen ONNX (no API key)
- 📊 **War Room** — Live ESI telemetry, burn rate charts, and incident command grid
- 🔒 **HIPAA Audit** — Tamper-evident SHA-256 log trail

---

## Quick Start

### Backend
```bash
cd intellidesk_backend
cp .env.example .env    # fill in Supabase + Gemini credentials
npm install
npm run dev
```

### Flutter App
```bash
cd intellidesk_app
flutter pub get
flutter run
```

### Docker (all services)
```bash
docker-compose up
```

---

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for a full technical breakdown.

---

## Demo Credentials

| Role | Email | Password |
|---|---|---|
| Patient / Student | `alex.rivera@campushealth.edu` | `demo123` |
| Chief Medical Officer | `dr.chen@medaccess.ai` | `admin123` |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile / Desktop | Flutter (Dart) |
| Backend | Node.js + TypeScript + Express |
| Real-time | Socket.io |
| Queue | BullMQ + Redis |
| Database | Supabase PostgreSQL + pgvector |
| ML | TensorFlow.js, Xenova Transformers, Qwen ONNX |
| OCR | Poppler (pdftotext) + Tesseract.js |
| PDF Reports | PDFKit |
