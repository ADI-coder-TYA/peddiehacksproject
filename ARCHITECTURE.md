# MedAccess AI System Architecture & Technical Specifications

This document outlines the detailed system design, data models, asynchronous background workers, and frontend MVVM structure of **MedAccess AI**.

---

## 1. System Topology

```
┌────────────────────────────────────────────────────────┐
│               MedAccess AI Client (Flutter)            │
│   • Patient Portal (Intake, Status Tracker, PFA Chat)  │
│   • Admin Clinical War Room (Triage, Telemetry, PDF)   │
└───────────────────────────▲────────────────────────────┘
                            │ REST / WebSocket (Socket.io)
┌───────────────────────────▼────────────────────────────┐
│              MedAccess Backend API (Express/TS)         │
│   • /api/v1/claims (CRUD & ESI Triage)                 │
│   • /api/v1/claims/:id/disburse (Multi-Rail Gateway)   │
│   • /api/v1/chat/claims/:id/messages (Qwen PFA AI)     │
│   • /api/v1/reports/clinical-audit-pdf (PDFKit Engine) │
└─────────────┬───────────────────────────┬──────────────┘
              │                           │
   Job Events │ Redis               Query │ SQL / RLS
              ▼                           ▼
┌───────────────────────────┐   ┌────────────────────────┐
│  BullMQ Intake Worker     │   │   Supabase PostgreSQL  │
│  • Poppler Layout OCR     │   │   • institutions       │
│  • Fraud Sentinel Hash    │   │   • profiles & roles   │
│  • DeepRank ESI ML Model  │   │   • health_funds       │
└───────────────────────────┘   │   • claims             │
                                │   • claim_messages     │
                                └────────────────────────┘
```

---

## 2. Database Schema (PostgreSQL / Supabase)

### 2.1 `institutions`
- `id` (UUID, PK)
- `name` (TEXT)
- `domain` (TEXT)
- `default_currency` (TEXT: `'INR'` | `'USD'`)
- `created_at` (TIMESTAMPTZ)

### 2.2 `profiles`
- `id` (UUID, PK) — References `auth.users.id`
- `email` (TEXT, UNIQUE)
- `full_name` (TEXT)
- `phone` (TEXT)
- `role` (TEXT: `'PATIENT'` | `'CLINICAL_ADMIN'` | `'AUDITOR'`)
- `institution_id` (UUID, FK ➔ `institutions.id`)
- `emergency_contact` (TEXT)

### 2.3 `health_funds`
- `id` (UUID, PK)
- `institution_id` (UUID, FK ➔ `institutions.id`)
- `name` (TEXT)
- `category` (TEXT)
- `total_allocated` (NUMERIC)
- `total_disbursed` (NUMERIC)
- `currency` (TEXT: `'INR'` | `'USD'`)

### 2.4 `claims`
- `id` (UUID, PK)
- `institution_id` (UUID, FK ➔ `institutions.id`)
- `patient_id` (UUID, FK ➔ `profiles.id`)
- `patient_phone` (TEXT)
- `description` (TEXT)
- `clinical_category` (TEXT)
- `esi_level` (TEXT: `'ESI_1_CRITICAL'` | `'ESI_2_EMERGENT'` | `'ESI_3_URGENT'` | `'ROUTINE'`)
- `crisis_severity_index` (NUMERIC, 0.00 to 1.00)
- `is_life_safety_alert` (BOOLEAN)
- `receipt_url` (TEXT)
- `receipt_image_hash` (TEXT)
- `extracted_bill_amount` (NUMERIC)
- `currency` (TEXT)
- `recommended_copay_amount` (NUMERIC)
- `approved_amount` (NUMERIC)
- `fraud_risk_score` (NUMERIC, 0.00 to 1.00)
- `fraud_flags` (TEXT)
- `status` (TEXT: `'Submitted'` | `'Triage Active'` | `'Disbursed'` | `'Flagged'` | `'Rejected'`)
- `clinical_notes` (TEXT)
- `payout_reference` (TEXT)
- `payout_method` (TEXT)
- `created_at` (TIMESTAMPTZ)

### 2.5 `claim_messages`
- `id` (UUID, PK)
- `claim_id` (UUID, FK ➔ `claims.id`)
- `sender` (TEXT: `'PATIENT'` | `'COUNSELOR_AI'` | `'CLINICAL_ADMIN'`)
- `message` (TEXT)
- `is_crisis_response` (BOOLEAN)
- `suggested_resources` (JSONB)
- `created_at` (TIMESTAMPTZ)

---

## 3. Flutter MVVM Architecture Pattern

```
lib/
├── models/                     # Domain Entities & Data Serialization
│   ├── claim.dart              # Medical claim record entity
│   ├── claim_message.dart      # Chat dialogue turn entity
│   ├── health_fund.dart        # Welfare pool balance entity
│   └── emergency_helpline.dart # 24/7 crisis hotline directory
├── services/                   # Infrastructure & Network Layer
│   ├── clinical_api_service.dart # REST API Client (CRUD, Payouts, PDF)
│   ├── socket_service.dart     # Socket.io connection & room manager
│   └── offline_sync_manager.dart # SharedPreferences offline fallback
├── providers/ (ViewModels)     # Reactive State Management
│   ├── claims_provider.dart    # Triage queue filtering & status updates
│   ├── clinical_chat_provider.dart # PFA conversation & typing state
│   ├── war_room_provider.dart  # Telemetry KPIs & fund liquidity
│   └── auth_provider.dart      # User role & session authentication
├── screens/                    # View Layer (UI Presentation)
│   ├── patient/                # Patient portal interfaces
│   │   ├── claim_intake_screen.dart
│   │   ├── clinical_chat_screen.dart
│   │   └── claim_status_screen.dart
│   └── admin/                  # Administrative & Clinical governance
│       ├── admin_war_room_screen.dart
│       └── admin_compliance_audit_screen.dart
└── theme/                      # Clinical Design System & ESI Colors
    └── app_theme.dart
```

---

## 4. API Specification

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/v1/claims` | List claims filtered by ESI level, status, or search |
| `POST` | `/api/v1/intake/web` | Submit new medical claim with invoice attachment |
| `GET` | `/api/v1/claims/:id` | Get claim details and triage breakdown |
| `POST` | `/api/v1/claims/:id/disburse` | Execute instant RazorpayX / Stripe payout & deduct fund |
| `POST` | `/api/v1/claims/:id/override` | Clinical admin override for ESI level or fraud flag |
| `POST` | `/api/v1/chat/claims/:id/messages` | Multi-turn PFA counselor interaction via Qwen ONNX |
| `GET` | `/api/v1/reports/clinical-audit-pdf` | Downloadable HIPAA compliance audit report |
| `GET` | `/health` | Service & database connectivity telemetry check |
