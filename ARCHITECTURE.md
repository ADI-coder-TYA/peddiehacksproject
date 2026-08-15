# MedAccess AI — System Architecture

> **Comprehensive technical reference:** topology, data models, background workers, API specification, and Flutter MVVM structure.

---

## 1. System Topology

```
┌──────────────────────────────────────────────────────────────────┐
│                  MedAccess AI Client (Flutter)                    │
│                                                                    │
│   Patient Portal                  Admin Clinical War Room          │
│   ─────────────                   ──────────────────────          │
│   • Claim Intake (PDF / photo)    • Triage Queue (ESI sorted)     │
│   • PFA Chat (Qwen AI)            • Health Fund Liquidity Panel   │
│   • Copay Status Tracker          • One-tap Payout Modal          │
│   • Emergency Helpline Directory  • Compliance Audit PDF          │
└────────────────────────▲─────────────────────────────────────────┘
                         │  REST + WebSocket (Socket.io)
┌────────────────────────▼─────────────────────────────────────────┐
│                 MedAccess Backend API (Express 5 / TypeScript)    │
│                                                                    │
│  /api/v1/auth             Auth + RBAC (JWT via Supabase)          │
│  /api/v1/intake/web       Async claim submission → BullMQ         │
│  /api/v1/claims           CRUD + ESI triage + status updates      │
│  /api/v1/claims/:id/disburse  Multi-rail payout execution         │
│  /api/v1/chat             Multi-turn PFA counselor (Qwen ONNX)    │
│  /api/v1/admin            Clinical admin overrides, telemetry     │
│  /api/v1/admin/reports    HIPAA audit PDF generation              │
└──────────────┬──────────────────────────────┬────────────────────┘
               │                              │
    Job Events │ Redis (BullMQ)        Query  │ SQL / RLS
               ▼                              ▼
┌─────────────────────────────┐   ┌──────────────────────────────┐
│  BullMQ Intake Worker        │   │  Supabase PostgreSQL          │
│  ─────────────────           │   │  ─────────────────────        │
│  • Poppler pdftotext -layout │   │  institutions                 │
│  • Tesseract.js OCR fallback │   │  profiles (RBAC)              │
│  • SHA-256 receipt hashing   │   │  students / student_rosters   │
│  • Fraud Sentinel checks     │   │  tickets / claims             │
│  • DeepRank CSI prediction   │   │  ticket_messages (PFA chat)   │
│  • Socket.io event broadcast │   │  health_funds / vouchers      │
│                              │   │  audit_logs                   │
│  ML Retraining Worker        │   │  (RLS per institution_id)     │
│  • Fine-tunes DeepRank on    │   └──────────────────────────────┘
│    resolved historical tix   │
│                              │
│  Notification Worker         │
│  • Email (Nodemailer/Resend) │
│  • SMS (Twilio)              │
└─────────────────────────────┘
```

---

## 2. Database Schema (PostgreSQL / Supabase)

All tables have **Row-Level Security (RLS)** enabled. The backend uses the `service_role` key to bypass RLS; the Flutter client uses the anon key with per-user JWT policies.

### 2.1 `institutions` — Multi-Tenancy Root
| Column | Type | Notes |
|---|---|---|
| `id` | TEXT (PK) | Slug e.g. `campus-health-001` |
| `name` | TEXT | Display name |
| `domain` | TEXT | Email domain whitelist |
| `currency` | TEXT | `'INR'` or `'USD'` |
| `created_at` | TIMESTAMPTZ | UTC |

### 2.2 `profiles` — Auth & RBAC
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | References `auth.users.id` |
| `email` | TEXT | Unique |
| `role` | TEXT | `'STUDENT'` \| `'ADMIN'` \| `'AUDITOR'` |
| `institution_id` | TEXT (FK) | Tenant scoping |
| `phone` | TEXT | Optional |
| `name` | TEXT | Display name |

### 2.3 `tickets` — Core Clinical Claim Record
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | Auto-generated |
| `institution_id` | TEXT (FK) | Tenant partition |
| `student_id` | UUID (FK) | References `students` |
| `raw_message` | TEXT | Original patient submission |
| `media_url` | TEXT | Invoice PDF / image URL |
| `parsed_category` | TEXT | Clinical category |
| `urgency_level` | TEXT | ESI level assigned by DeepRank |
| `status` | TEXT | `Pending` → `Processing` → `Approved` / `Rejected` / `Flagged` |
| `calculated_amount` | NUMERIC | OCR-extracted bill total |
| `currency` | TEXT | `'INR'` or `'USD'` |
| `crisis_severity_index` | NUMERIC (0–1) | DeepRank output |
| `dropout_risk_score` | NUMERIC (0–1) | LSTM attrition model output |
| `recommended_grant_amount` | NUMERIC | Grant optimizer output |
| `fraud_risk_score` | NUMERIC (0–1) | Fraud Sentinel score |
| `fraud_flags` | TEXT | Comma-separated flag reasons |
| `receipt_image_hash` | TEXT | SHA-256 for deduplication |
| `anomaly_reconstruction_score` | NUMERIC | Autoencoder MSE |
| `payout_reference` | TEXT | RazorpayX / Stripe txn ID |
| `payout_method` | TEXT | UPI / BANK / VOUCHER |
| `embedding` | vector(768) | Semantic embedding for policy match |

### 2.4 `ticket_messages` — PFA Chat History
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `ticket_id` | UUID (FK) | Parent claim |
| `sender` | TEXT | `'STUDENT'` \| `'COUNSELOR_AI'` \| `'HUMAN_ADMIN'` |
| `message` | TEXT | Message body |
| `is_crisis_response` | BOOLEAN | True if self-harm keywords detected |
| `suggested_resources` | JSONB | Emergency hotline cards array |

### 2.5 `health_funds` / `funds`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `institution_id` | TEXT (FK) | |
| `fund_name` | TEXT | e.g. "Emergency Medical Copay Fund" |
| `total_budget` | NUMERIC | Allocated budget |
| `allocated_amount` | NUMERIC | Amount disbursed to date |
| `currency` | TEXT | |

### 2.6 `audit_logs`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `institution_id` | TEXT | |
| `ticket_id` | UUID (FK) | Optional |
| `action_type` | TEXT | e.g. `DISBURSEMENT`, `ESI_OVERRIDE`, `FRAUD_FLAG` |
| `actor_type` | TEXT | `SYSTEM` / `ADMIN` / `AI` |
| `details` | JSONB | Structured audit payload |

### 2.7 `vouchers`
| Column | Type | Notes |
|---|---|---|
| `id` | UUID (PK) | |
| `ticket_id` | UUID (FK) | |
| `voucher_code` | TEXT | e.g. `EDU-GRANT-ABC123` |
| `amount` | NUMERIC | |
| `status` | TEXT | `Active` / `Redeemed` / `Expired` |

---

## 3. Background Workers (BullMQ / Redis)

### 3.1 Intake Worker (`intakeWorker.ts`)
The primary processing pipeline for every submitted claim. Runs on the `clinical-intake-queue`.

```
Job Received (claim_id, raw_message, media_url)
         │
         ├─ Step 1: Receipt Parsing
         │    └── pdftotext -layout → Tesseract.js fallback → extractInvoiceTotal()
         │
         ├─ Step 2: NLP Feature Extraction
         │    └── word_count, urgent_keyword_count, sentiment_score, historical_count
         │
         ├─ Step 3: Fraud Sentinel
         │    ├── SHA-256 hash lookup in `tickets.receipt_image_hash`
         │    ├── 7-day velocity check per patient_phone
         │    └── Autoencoder anomaly score
         │
         ├─ Step 4: DeepRank Inference
         │    └── predict([word_count, urgent_kw, sentiment, hist_count]) → CSI
         │
         ├─ Step 5: ESI Tier Assignment
         │    └── CSI ≥ 0.85 → ESI_1 | 0.60 → ESI_2 | 0.35 → ESI_3 | else ROUTINE
         │
         ├─ Step 6: Grant Optimizer
         │    └── Compute recommended_copay_amount from CSI + fund liquidity
         │
         ├─ Step 7: Policy Match (RAG)
         │    └── Vector embedding similarity → matched_policy_name
         │
         └─ Step 8: Supabase Update + Socket.io Broadcast
              └── ticket.status = 'Triage Active' + real-time push to admin dashboard
```

### 3.2 ML Retraining Worker (`mlRetrainingWorker.ts`)
- Triggered periodically or by admin action
- Loads resolved tickets from Supabase as labeled training data
- Calls `fineTuneDeepRankModel()` to update weights on real outcome data
- Saves updated model weights back to `./models/deep_rank/`

### 3.3 Notification Worker (`notificationWorker.ts`)
- Sends email (Nodemailer / Resend) for claim status changes
- SMS via Twilio for critical ESI-1 alerts
- Queued via BullMQ `notification-queue`

---

## 4. REST API Specification

### Public / Auth
| Method | Route | Description |
|---|---|---|
| `POST` | `/api/v1/auth/signup` | Register patient or admin |
| `POST` | `/api/v1/auth/login` | Get JWT + user profile |
| `GET` | `/api/v1/auth/profile` | Authenticated user profile |

### Claim Intake
| Method | Route | Description |
|---|---|---|
| `POST` | `/api/v1/intake/web` | Submit new claim (multipart: text + PDF/image) |
| `GET` | `/api/v1/claims` | List claims (filtered by ESI, status, search) |
| `GET` | `/api/v1/claims/:id` | Get full claim details + triage breakdown |

### Clinical Admin (ADMIN role required)
| Method | Route | Description |
|---|---|---|
| `POST` | `/api/v1/claims/:id/disburse` | Execute RazorpayX / Stripe payout |
| `POST` | `/api/v1/claims/:id/override` | ESI level / fraud flag override with notes |
| `GET` | `/api/v1/admin/telemetry` | KPI dashboard: fund liquidity, ESI distribution |
| `GET` | `/api/v1/admin/reports` | HIPAA compliance audit PDF (PDFKit) |
| `GET` | `/api/v1/admin/knowledge` | Institutional policy knowledge base |

### PFA Chat
| Method | Route | Description |
|---|---|---|
| `POST` | `/api/v1/chat` | Send message, get Qwen PFA AI reply |
| `GET` | `/api/v1/chat/:ticketId/messages` | Retrieve full chat history for a claim |

### Health Check
| Method | Route | Description |
|---|---|---|
| `GET` | `/health` | Service + DB connectivity + ML model status |

---

## 5. Flutter MVVM Architecture

```
lib/
├── main.dart                          # App entry, Provider tree, route table
├── config/                            # API base URLs, environment flags
├── models/                            # Immutable domain entities
│   ├── claim.dart                     # Medical claim entity (fromJson/toJson)
│   ├── claim_message.dart             # PFA chat turn entity
│   ├── health_fund.dart               # Welfare fund balance entity
│   └── emergency_helpline.dart        # Crisis hotline directory model
├── services/                          # Network & infrastructure layer
│   ├── clinical_api_service.dart      # REST client (claims, payouts, PDF)
│   ├── socket_service.dart            # Socket.io room manager + event stream
│   └── offline_sync_manager.dart      # SharedPreferences offline fallback
├── providers/ (ViewModels)            # Reactive state (ChangeNotifier)
│   ├── auth_provider.dart             # Session, role, JWT refresh
│   ├── claims_provider.dart           # Triage queue + ESI filter state
│   ├── clinical_chat_provider.dart    # PFA conversation + typing indicator
│   ├── war_room_provider.dart         # Telemetry KPIs + fund liquidity
│   ├── ticket_provider.dart           # Patient-side ticket tracking
│   ├── preferences_provider.dart      # User settings + theme
│   └── job_tracking_manager.dart      # Background job poll + status
├── screens/                           # View layer (UI presentation)
│   ├── auth/
│   │   ├── admin_signup_screen.dart
│   │   └── patient_login_screen.dart
│   ├── onboarding/                    # Intro + institution selection
│   ├── patient/                       # Patient portal
│   │   ├── patient_main_screen.dart   # Tab navigator (intake / chat / status)
│   │   ├── claim_intake_screen.dart   # PDF/image upload + text submission
│   │   ├── clinical_chat_screen.dart  # Real-time PFA chat UI
│   │   └── claim_status_screen.dart   # ESI badge + payout tracker
│   ├── admin/                         # Admin governance
│   │   ├── admin_main_screen.dart     # Navigation hub
│   │   ├── admin_war_room_screen.dart # Triage queue + one-tap payout
│   │   ├── admin_telemetry_dashboard_screen.dart  # FL Chart KPIs
│   │   ├── admin_health_funds_screen.dart         # Fund liquidity management
│   │   ├── admin_knowledge_base_screen.dart       # Policy RAG search
│   │   └── admin_compliance_audit_screen.dart     # HIPAA audit PDF download
│   └── profile/
└── theme/
    └── app_theme.dart                 # Clinical design system, ESI color tokens
```

---

## 6. WebSocket Events (Socket.io)

| Event | Direction | Payload |
|---|---|---|
| `join-institution` | Client → Server | `{ institutionId }` |
| `ticket-created` | Server → Client | Full ticket object |
| `ticket-updated` | Server → Client | `{ ticketId, status, esiLevel, csi }` |
| `payout-completed` | Server → Client | `{ ticketId, txnRef, amount }` |
| `fraud-flagged` | Server → Client | `{ ticketId, flagReasons }` |

---

## 7. Security Architecture

```
Request → CORS → JWT Middleware (requireAuth)
                        │
                        ▼
              requireRole(['ADMIN']) — blocks non-admin routes
                        │
                        ▼
              tenantScopeMiddleware — injects institution_id
              from JWT claims into all DB queries
                        │
                        ▼
              Supabase RLS — enforces data isolation
              at the database level (service_role bypasses for backend)
```

- **HIPAA-aligned audit trail:** every disbursement, override, and fraud decision recorded in `audit_logs` with `action_type`, `actor_type`, and full JSONB `details`
- **Receipt integrity:** SHA-256 hashes stored in `receipt_image_hash` at intake time
- **Tamper-evident PDFs:** SHA-256 checksum printed on every audit report

---

## 8. Deployment

### Docker Compose
```yaml
services:
  backend:
    build: ./intellidesk_backend
    ports: ["3000:3000"]
    environment:
      - SUPABASE_URL
      - SUPABASE_SERVICE_ROLE_KEY
      - REDIS_URL
      - RAZORPAY_KEY_ID
      - RAZORPAY_KEY_SECRET
    depends_on: [redis]
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
```

### Environment Variables (`.env`)
| Variable | Description |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Backend service role key (bypasses RLS) |
| `SUPABASE_ANON_KEY` | Flutter client anon key |
| `REDIS_URL` | BullMQ Redis connection string |
| `RAZORPAY_KEY_ID` | RazorpayX API key |
| `RAZORPAY_KEY_SECRET` | RazorpayX API secret |
| `RAZORPAYX_ACCOUNT_NUMBER` | Fund account for payouts |
| `STRIPE_SECRET_KEY` | Stripe secret for USD payouts |
| `TWILIO_ACCOUNT_SID` | SMS notifications |
| `PORT` | HTTP server port (default `3000`) |
