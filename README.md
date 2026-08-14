# MedAccess AI
> **Autonomous Clinical Triage, Medical Claim Verification & Emergency Copay Engine**

[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-blue.svg)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue.svg)](https://www.typescriptlang.org)
[![TensorFlow.js](https://img.shields.io/badge/TensorFlow.js-DeepRank-orange.svg)](https://js.tensorflow.org)
[![ONNX](https://img.shields.io/badge/ONNX-Qwen2.5--0.5B-purple.svg)](https://github.com/huggingface/transformers.js)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🏥 Overview

**MedAccess AI** is an autonomous clinical welfare and healthcare access platform designed to eliminate financial bottlenecks during acute medical emergencies. 

When a patient or student experiences an emergency, delays in insurance adjudication or out-of-pocket copay obligations can lead to severe health deterioration. MedAccess AI combines **local zero-cost ML models**, **layout-aware invoice OCR**, **perceptual fraud detection**, **real-time Psychological First Aid (PFA)**, and **instant multi-rail copay disbursements (RazorpayX / Stripe)** to deliver verified financial relief in minutes.

---

## ⚡ End-to-End Pipeline Architecture

```
[Patient submits Hospital PDF or SOS Message]
                     │
                     ▼
[Local Qwen2.5-0.5B PFA Counselor] ──► Instant empathetic reply & Tele-MANAS (14416) / 988 Hotlines
                     │
                     ▼
[IntakeWorker (BullMQ clinical-intake-queue)]
   ├── Poppler-Utils Layout Parser  ──► Extracts exact hospital bill total (e.g. ₹4,305.00 / $500.00)
   ├── Fraud Sentinel Engine        ──► SHA-256 duplicate perceptual hash & billing velocity checks
   └── DeepRank ESI Classifier      ──► Computes Crisis Severity Index (CSI) & Assigns ESI Tiers (1 to 4)
                     │
                     ▼
[Admin War Room Real-Time Dashboard]
   ├── Instant Payout Modal         ──► One-tap RazorpayX UPI / Stripe Instant Payouts
   └── Executive Audit PDF Engine   ──► HIPAA compliance audit report with tamper-evident SHA-256 hash
```

---

## 🩺 Emergency Severity Index (ESI) Triage Protocol

MedAccess AI classifies incoming medical claims using our custom **DeepRank Neural Model** combined with local sentiment extraction:

| ESI Level | Clinical Severity Description | Crisis Severity Index (CSI) | Copay Grant Coverage | SLA Target |
|---|---|---|---|---|
| **ESI 1 (Critical)** | Immediate resuscitation, severe trauma, unconsciousness, acute bleeding | `CSI >= 0.85` or Life-Safety Trigger | **100% Coverage** (Up to ₹80,000 / $2,500) | `< 2 mins` |
| **ESI 2 (Emergent)** | High distress, severe pain, critical insulin/medication shortage | `0.60 <= CSI < 0.85` | **80% Coverage** (Up to ₹40,000 / $1,500) | `< 10 mins` |
| **ESI 3 (Urgent)** | Moderate distress, urgent diagnostic imaging, acute fracture | `0.35 <= CSI < 0.60` | **50% Coverage** (Up to ₹20,000 / $800) | `< 30 mins` |
| **Routine** | Standard outpatient consultation, scheduled lab tests | `CSI < 0.35` | **30% Micro-Grant** (Up to ₹5,000 / $200) | `< 2 hours` |

---

## 🚀 Key Modules & Capabilities

### 1. 🧠 24/7 Psychological First Aid (PFA) & Clinical Counselor
- **Local ONNX Execution**: Powered by `onnx-community/Qwen2.5-0.5B-Instruct` (quantized `q4` dtype) running on CPU via `@xenova/transformers`. Requires **zero external cloud API costs** and operates offline.
- **Immediate Life-Safety Helpline Routing**:
  - 📞 **Tele-MANAS (Govt of India)**: `14416` / `1800-891-4416`
  - 📞 **Vandrevala Mental Health Helpline**: `+91 9999 666 555`
  - 📞 **988 Suicide & Crisis Lifeline (US)**: `988`
  - 🚨 **Campus 24/7 Medical Emergency Desk**: `1800-MED-ACCESS`

### 2. 📑 Layout-Preserving Invoice OCR (`Poppler` + `Tesseract`)
- Extracts line items, patient details, and total billed amounts from hospital invoices and pharmacy receipts.
- Calculates OCR confidence and flags discrepancies between claimed amounts and scanned totals.

### 3. 🛡️ Fraud Sentinel & Perceptual Hash Verification
- Generates 64-bit cryptographic and perceptual SHA-256 hashes of all receipt uploads.
- Detects recycled receipts, altered invoice dates, and suspicious claim velocity across institutions.

### 4. 💳 Multi-Rail Copay Disbursement Engine
- **INR Transactions**: Automated IMPS / UPI payouts via **RazorpayX API**.
- **USD Transactions**: Automated instant transfers via **Stripe Instant Payouts / ACH**.
- **Failsafe Sandbox**: Generates cryptographically verifiable audit receipts (`TXN_MED_${timestamp}_OK`) when running in demo/offline modes.

### 5. 📑 HIPAA Audit & Executive PDF Generator
- Produces tamper-evident clinical governance reports for institutional deans, hospital boards, and state auditors using `PDFKit`.
- Computes SHA-256 integrity checksums over all adjudicated records.

---

## 🛠️ Tech Stack

| Layer | Technologies |
|---|---|
| **Frontend UI** | Flutter 3.29+ (Dart), Provider (MVVM), Google Fonts, FL Chart, Socket.io Client |
| **Backend Services** | Node.js, Express, TypeScript, BullMQ, Redis |
| **Database & Auth** | Supabase (PostgreSQL), Row-Level Security (RLS) |
| **Machine Learning** | TensorFlow.js (DeepRank), Xenova Transformers, Qwen2.5 ONNX |
| **Document Parsing** | Poppler (`pdftotext`), Tesseract OCR |
| **Payment Rails** | RazorpayX Payouts (UPI/IMPS), Stripe Instant Payouts |
| **PDF Reporting** | PDFKit |

---

## 🏁 Quick Start Guide

### Prerequisites
- **Node.js** (v18 or v20 LTS)
- **Flutter SDK** (v3.29+)
- **Redis Server** (for BullMQ background jobs)

### 1. Backend Setup
```bash
cd intellidesk_backend
cp .env.example .env
npm install
npm run dev
```

### 2. Flutter Mobile / Web Client Setup
```bash
cd intellidesk_app
flutter pub get
flutter run
```

---

## 👥 Demo User Credentials

| Role | Email | Password | Permissions |
|---|---|---|---|
| **Patient / Student** | `alex.rivera@campushealth.edu` | `demo123` | Submit claims, 24/7 PFA chat, track copay status |
| **Chief Medical Officer (Admin)** | `dr.chen@medaccess.ai` | `admin123` | Clinical War Room, ESI triage overrides, copay disbursement |

---

## 🔒 Security & HIPAA Compliance

- **Role-Based Access Control (RBAC)**: Enforced across all endpoints (`PATIENT`, `CLINICAL_ADMIN`, `AUDITOR`).
- **Data Isolation**: Institutional multitenancy enforced via `institution_id` partition keys.
- **Audit Trails**: All clinical overrides, ESI alterations, and disbursements are recorded with cryptographic timestamps in `audit_logs`.

---

## 📄 License
MedAccess AI is licensed under the [MIT License](./LICENSE).
