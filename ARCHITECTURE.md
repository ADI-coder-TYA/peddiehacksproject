# MedAccess AI — Architecture & Technical Reference

## 1. System Overview

MedAccess AI is an edge-first autonomous clinical triage, medical claim verification, and emergency copay disbursement platform. It is designed for universities, enterprise workplaces, and community health networks.

## 2. Components

### 2.1 Flutter Frontend (`intellidesk_app`)
| Layer | Files |
|---|---|
| Theme | `lib/theme/app_theme.dart` |
| Models | `lib/models/` (Claim, ESI, ClinicalPolicy, Ticket) |
| State (Provider) | `lib/providers/` (Auth, Claims, Jobs, Accessibility) |
| Services | `lib/services/` (API client, Socket.io, Offline SQLite) |
| Screens | `lib/screens/` (Auth, Student portal, Admin portal, Profile) |
| Widgets | `lib/widgets/` (GlassCard, EsiBadge, PfaChat, IncidentGrid, HipaaLog, SlaSimulator) |

### 2.2 Node.js Backend (`intellidesk_backend`)
| Layer | Files |
|---|---|
| Server | `src/server.ts` (Express + Socket.io) |
| Routes | `src/routes/` (intake, auth, telemetry, admin, knowledge, reports, simulation) |
| ML Pipelines | `src/services/` (deepRankModel, anomalyModel, receiptParser, fraudSentinel, crisisCounselorService) |
| Utilities | `src/utils/` (categoryClassifier, featureExtractor, grantExtractor) |
| Queue | BullMQ + Redis (async intake worker) |
| Database | Supabase PostgreSQL + pgvector (vector embeddings) |

## 3. ML Model Stack
1. **TF.js DeepRank** — Clinical Severity Index (CSI) + grant amount prediction
2. **TF.js Autoencoder** — Anomaly / fraud claim detection
3. **Xenova `all-MiniLM-L6-v2`** — Dense semantic embeddings + category classification
4. **Qwen ONNX** — Local offline Psychological First Aid counselor (no API key)
5. **Tesseract + pdftotext** — Layout-aware hospital invoice OCR

## 4. ESI Grading Thresholds
| ESI Level | Label | CSI Range |
|---|---|---|
| ESI-1 | Resuscitation / Critical | ≥ 0.85 |
| ESI-2 | Emergent / High Distress | 0.60 – 0.84 |
| ESI-3 | Urgent / Routine Copay | < 0.60 |

## 5. Data Flow
```
Patient → Submit PDF/Image claim
     ↓
OCR (pdftotext + Tesseract) extracts line items
     ↓
DeepRank → CSI score → ESI level
Autoencoder → Fraud risk score
FraudSentinel → SHA-256 duplicate hash check
     ↓
Grant engine allocates copay amount
     ↓
Socket.io pushes status to Flutter UI
```

## 6. Security & Compliance
- HIPAA-compliant tamper-evident SHA-256 audit logs
- Supabase Row Level Security (RLS) per tenant
- JWT-based role access (Patient / Clinician / Chief Medical Officer)
- Offline mode: claims queued in SQLite, synced on reconnect

## 7. Deployment
- Docker Compose: backend + Redis + PostgreSQL
- Flutter: Android, iOS, macOS, Windows, Web (PWA)
- Edge deployment: models run on-device / on-prem (no external API calls required)
