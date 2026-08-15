# MedAccess AI — Backend Reference

> **Complete guide to the Node.js/TypeScript backend:** server bootstrap, routes, services, middleware, workers, and configuration.

---

## 1. Project Overview

| Item | Value |
|---|---|
| **Runtime** | Node.js 18+ (ESM modules) |
| **Framework** | Express 5 |
| **Language** | TypeScript 5 |
| **Queue** | BullMQ + Redis |
| **Database** | Supabase (PostgreSQL) |
| **ML Runtime** | TensorFlow.js Node (native bindings) |
| **Entry point** | `src/server.ts` |

---

## 2. Directory Structure

```
intellidesk_backend/
├── src/
│   ├── server.ts               # HTTP server bootstrap + route mount
│   ├── config/                 # Supabase client + env config
│   ├── controllers/
│   │   ├── claimsController.ts # Claim CRUD, ESI triage, payout dispatch
│   │   └── chatController.ts   # PFA counselor message handler
│   ├── routes/
│   │   ├── auth.ts             # Signup, login, profile
│   │   ├── asyncIntake.ts      # Claim submission → BullMQ enqueue
│   │   ├── claims.ts           # Claim read endpoints
│   │   ├── chat.ts             # PFA chat endpoints
│   │   ├── admin.ts            # Admin CRUD + override endpoints
│   │   ├── telemetry.ts        # KPI dashboard data
│   │   ├── reports.ts          # Audit PDF generation
│   │   ├── knowledge.ts        # Policy knowledge base (RAG)
│   │   ├── simulation.ts       # Crisis scenario simulation
│   │   ├── patients.ts         # Patient profile endpoints
│   │   └── workflow_dispatch.ts # ML retraining workflow trigger
│   ├── services/               # Business logic layer (25 services)
│   ├── middleware/             # Auth, RBAC, tenant scoping
│   ├── ml/                     # TF.js model training definitions
│   ├── workers/                # BullMQ background job processors
│   ├── types/                  # Shared TypeScript interfaces
│   └── utils/                  # Shared utility functions
├── scripts/                    # One-off seed and test scripts
├── data/                       # Training CSVs
├── models/                     # Saved TF.js model weights
└── Dockerfile / docker-compose.yml
```

---

## 3. Server Bootstrap (`server.ts`)

The server initializes in this order:

```
1. ensureStorageBucketsExist()     — Create Supabase storage buckets if missing
2. DatabaseService.checkDatabaseHealth()  — Verify schema + connectivity
3. Promise.all([
     loadOrTrainLSTMModel(),
     loadOrTrainGrantOptimizerModel(),
     loadOrTrainDeepRankModel(),
     loadOrTrainAnomalyModel()
   ])                              — Load TF.js model weights from disk
4. server.listen(PORT)            — Start HTTP on 0.0.0.0:3000
5. startWorkers()                  — Spin up BullMQ intake + notification workers
```

If model weight files are missing, each loader logs a warning and sets the model to `null`. Inference falls back to neutral defaults (CSI = 0.5) so the server never crashes on startup.

---

## 4. Middleware Stack

### `requireAuth` — JWT Verification
```typescript
// src/middleware/authMiddleware.ts
// Reads Authorization: Bearer <token>
// Verifies via Supabase Auth API
// Attaches user object to req.user
```

### `requireRole(roles[])` — RBAC Guard
```typescript
// Checks req.user.role against allowed roles
// Returns 403 if role not in list
// Admin routes require ['ADMIN']
```

### `tenantScopeMiddleware` — Institution Isolation
```typescript
// Extracts institution_id from JWT claims
// Attaches to req.institutionId
// All DB queries are implicitly scoped to this tenant
// Prevents cross-institution data leakage
```

---

## 5. Route Reference

### Auth (`/api/v1/auth`)

**POST `/signup`**
```json
Request:  { "email": "...", "password": "...", "role": "STUDENT", "institution_id": "..." }
Response: { "user": {...}, "session": { "access_token": "..." } }
```

**POST `/login`**
```json
Request:  { "email": "...", "password": "..." }
Response: { "user": {...}, "session": { "access_token": "..." } }
```

**GET `/profile`**  
Returns authenticated user profile including role and institution.

---

### Claim Intake (`/api/v1/intake`)

**POST `/web`** — Submit a new medical claim  
Content-Type: `multipart/form-data`

| Field | Type | Required | Description |
|---|---|---|---|
| `message` | string | ✅ | Patient's description of their emergency |
| `studentPhone` | string | ✅ | Phone number for velocity checks |
| `institutionId` | string | ✅ | Tenant identifier |
| `receipt` | file | ❌ | Hospital invoice (PDF / PNG / JPG) |
| `studentName` | string | ❌ | Patient display name |

**Response (202 Accepted):**
```json
{
  "ticketId": "uuid-...",
  "status": "Processing",
  "message": "Claim submitted. Clinical triage is in progress."
}
```

Processing continues asynchronously via BullMQ. Real-time status updates arrive over Socket.io.

---

### Claims (`/api/v1/claims`)

**GET `/`** — List claims  
Query params: `?status=Pending&esiLevel=ESI_1_CRITICAL&search=fracture&limit=20&offset=0`

**GET `/:id`** — Get full claim with triage breakdown  
Returns: ticket object + ML scores + OCR result + fraud report + chat history count

---

### Admin (`/api/v1/admin` — ADMIN role required)

**POST `/claims/:id/disburse`**
```json
Request:  {
  "amount": 5000,
  "payoutMethod": "RAZORPAY_UPI",
  "studentVpa": "student@okaxis",
  "approvalNotes": "ESI-2 verified, fund pool C"
}
Response: {
  "transactionReference": "pout_abc12345",
  "disbursedAmount": 5000,
  "disbursementMethod": "RAZORPAY_UPI",
  "timestamp": "2026-08-15T13:00:00Z"
}
```

**POST `/claims/:id/override`**
```json
Request:  { "esiLevel": "ESI_1_CRITICAL", "notes": "Verified trauma via hospital call" }
Response: { "success": true, "updatedClaim": {...} }
```

**GET `/telemetry`** — Returns KPI metrics:
- Total claims by ESI level
- Fund liquidity per pool
- Average adjudication time
- Fraud flag rate
- 30-day disbursement volume

**GET `/reports`** — Triggers HIPAA audit PDF generation  
Returns binary PDF stream with `Content-Disposition: attachment`

---

### PFA Chat (`/api/v1/chat`)

**POST `/`** — Send a patient message, receive PFA AI reply
```json
Request:  {
  "ticketId": "uuid-...",     // null for pre-claim chat
  "message": "I can't afford my insulin, I don't know what to do",
  "history": [
    { "sender": "STUDENT", "message": "..." },
    { "sender": "COUNSELOR_AI", "message": "..." }
  ]
}

Response: {
  "reply": "I hear how frightening this is...",
  "isCrisisResponse": false,
  "requiresConfirmation": true,
  "isTicketLogged": false,
  "resources": null,
  "latencyMs": 1240,
  "messageId": "uuid-..."
}
```

---

## 6. Core Services

### Receipt Parser (`receiptParser.ts`)
Extracts bill totals from hospital invoices:

```
Input: media_url (HTTPS / data URI / local file path)
         │
         ├── PDF → pdftotext -layout (Poppler) → preserve table alignment
         │         fallback → pdf-parse (in-memory)
         │
         └── Image → Tesseract.js (eng.traineddata) → OCR text
                         │
                         └── extractInvoiceTotal(text)
                               ├── High-precision regex anchors (TOTAL DUE, GRAND TOTAL, etc.)
                               ├── INR vs USD currency detection
                               └── Fallback: highest numeric value in document
```

Supported formats: PDF, PNG, JPG/JPEG, GIF, BMP, TIFF, WebP

### Fraud Sentinel (`fraudSentinel.ts`)
Three-layer fraud detection:

```
Layer 1: Duplicate Receipt (SHA-256)
  computeImageHash(mediaUrl) → compare against tickets.receipt_image_hash
  → +0.50 risk if duplicate found

Layer 2: Claim Velocity
  7-day window per patient_phone
  → +0.35 if ≥ 3 claims in 7 days (non life-safety)
  → Threshold gaming: +0.30 if repeated micro-grants near $200

Layer 3: ML Anomaly
  predictAnomalyScore(features) via Autoencoder
  → +0.40 if reconstruction MSE ≥ 0.75 (non life-safety)

Final: riskScore = min(1.0, sum)
       isFlagged = riskScore ≥ 0.60 (or 0.50 for life-safety)
```

### Disbursement Service (`disbursementService.ts`)

Supports three payout rails:

**RAZORPAY_UPI (INR, instant)**
```typescript
razorpayInstance.payouts.create({
  amount: amount * 100,  // paise
  mode: 'UPI',
  fund_account: { account_type: 'vpa', vpa: { address: studentVpa } }
})
```

**RAZORPAY_BANK (INR, IMPS)**
```typescript
// mode: 'IMPS', fund_account.account_type: 'bank_account'
```

**VOUCHER (offline / sandbox)**
```typescript
// Generates EDU-GRANT-XXXXXX code
// Inserts into vouchers table
// Redeemable at campus finance office
```

### PDF Report Service (`pdfReportService.ts`)
Generates HIPAA-compliant audit PDFs using PDFKit:
- Clinical governance header with institution branding
- Claim-by-claim adjudication log with ML scores
- Disbursement ledger with transaction references
- SHA-256 integrity checksum of report content
- Signed timestamp from server

### Socket Manager (`socketManager.ts`)
Real-time event broadcasting via Socket.io:
```typescript
// Clients join a room per institution_id
io.to(institutionId).emit('ticket-updated', { ticketId, status, esiLevel, csi });
io.to(institutionId).emit('payout-completed', { ticketId, txnRef, amount });
```

### Audit Logger (`auditLogger.ts`)
Every clinically significant action records to `audit_logs`:
```typescript
await logAudit({
  institution_id,
  ticket_id,
  action_type: 'DISBURSEMENT',
  actor_type: 'ADMIN',
  details: { amount, method, approvalNotes, txnRef }
});
```

### Email Dispatch (`emailDispatch.ts`)
- Uses Nodemailer (SMTP) with Resend as a fallback
- Templates: claim received, triage complete, payout sent, fraud flag notification

---

## 7. Background Workers

### IntakeWorker (`workers/intakeWorker.ts`)

Processes jobs from the `clinical-intake-queue` BullMQ queue.

**Job payload:**
```typescript
{
  ticketId: string,
  rawMessage: string,
  mediaUrl?: string,
  studentPhone: string,
  institutionId: string
}
```

**Processing steps** (see [ARCHITECTURE.md](../ARCHITECTURE.md) §3.1 for full pipeline diagram):
1. Receipt OCR extraction
2. NLP feature vector extraction  
3. Fraud Sentinel evaluation
4. DeepRank CSI prediction
5. ESI tier assignment
6. Grant optimizer recommendation
7. Policy RAG match
8. Supabase update + Socket.io broadcast

**Retry policy:** 3 attempts, exponential backoff

### ML Retraining Worker (`workers/mlRetrainingWorker.ts`)

Triggered by admin via `POST /api/v1/workflow/retrain`:
1. Queries resolved tickets from Supabase as training examples
2. Calls `fineTuneDeepRankModel(pastTickets)` — 5 epochs online learning
3. Updates `models/deep_rank/` weights on disk
4. Logs retraining loss to audit_logs

### Notification Worker (`workers/notificationWorker.ts`)

Processes jobs from `notification-queue`:
- Email via Nodemailer/Resend for status changes
- SMS via Twilio for ESI-1 critical alerts
- Internal Socket.io push for real-time dashboard updates

---

## 8. Database Service (`services/dbService.ts`)

`DatabaseService` wraps all Supabase queries with consistent error handling and tenant scoping:

```typescript
// Example: get claims for an institution, filtered by ESI
await DatabaseService.getClaims({
  institutionId: 'campus-001',
  esiLevel: 'ESI_1_CRITICAL',
  status: 'Pending',
  limit: 20
});

// Health check (used by /health endpoint and startup)
await DatabaseService.checkDatabaseHealth();
// Returns: { status: 'healthy' | 'degraded', claimsReady, fundsReady }
```

---

## 9. Environment Configuration

```bash
# .env (copy from .env.example)

# Supabase
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # Full database access (backend only)
SUPABASE_ANON_KEY=eyJ...           # Flutter client key

# Redis (BullMQ)
REDIS_URL=redis://localhost:6379

# Payment Rails
RAZORPAY_KEY_ID=rzp_live_...
RAZORPAY_KEY_SECRET=...
RAZORPAYX_ACCOUNT_NUMBER=2323230039262626
STRIPE_SECRET_KEY=sk_live_...

# Notifications
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=+1...
RESEND_API_KEY=re_...
SMTP_HOST=smtp.gmail.com
SMTP_USER=...
SMTP_PASS=...

# App
PORT=3000
NODE_ENV=production
```

---

## 10. NPM Scripts

| Script | Command | Description |
|---|---|---|
| `dev` | `tsx src/server.ts` | Development server with hot reload |
| `build` | `tsc` | Compile TypeScript to `dist/` |
| `start` | `node dist/src/server.js` | Production server |
| `train:ml` | `tsx scripts/generate_training_data.ts && tsx src/ml/train_all.ts` | Generate data + train all ML models |
| `seed:policies` | `tsx scripts/seed_policies.ts` | Seed institutional policy KB |
| `seed:funds` | `tsx scripts/seed_funds.ts` | Seed health fund pools |
| `seed:audits` | `tsx scripts/seed_audit_logs.ts` | Seed sample audit log data |
| `seed:all` | runs all three seed scripts | Full database seed |
| `test:workflows` | `tsx scripts/testMedAccessSuite.ts` | Integration test suite |
| `test:advanced` | `tsx scripts/testMedAccessAdvancedSuite.ts` | Advanced integration tests |
