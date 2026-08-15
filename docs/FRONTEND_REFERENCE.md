# MedAccess AI — Frontend Reference

> **Complete guide to the Flutter client:** MVVM architecture, Provider state management, screens, services, theme system, and real-time Socket.io integration.

---

## 1. Project Overview

| Item | Value |
|---|---|
| **Framework** | Flutter 3.29+ (Dart SDK ^3.10.7) |
| **Architecture** | MVVM via Provider |
| **State Management** | `provider` ^6.1.5 |
| **Charting** | `fl_chart` ^1.2.0 |
| **Real-time** | `socket_io_client` ^3.1.6 |
| **Typography** | `google_fonts` ^8.2.1 |
| **File Upload** | `file_picker` + `image_picker` |
| **Offline** | `shared_preferences` ^2.5.5 |
| **Notifications** | `flutter_local_notifications` ^22.2.0 |
| **Networking** | `http` ^1.6.0 |

---

## 2. MVVM Architecture Pattern

```
┌─────────────────────────────────────────────────┐
│                   View Layer                      │
│              (screens/*.dart)                     │
│   Reads state via context.watch<ProviderX>()      │
│   Dispatches actions via context.read<ProviderX>  │
└──────────────────────┬──────────────────────────┘
                       │ ChangeNotifier
┌──────────────────────▼──────────────────────────┐
│                ViewModel Layer                    │
│             (providers/*.dart)                    │
│   Holds UI state, fetches data, processes events  │
└──────────────────────┬──────────────────────────┘
                       │ async calls
┌──────────────────────▼──────────────────────────┐
│               Infrastructure Layer               │
│           (services/*.dart)                      │
│   REST API calls, Socket.io, SharedPreferences   │
└─────────────────────────────────────────────────┘
```

---

## 3. Provider Tree (`main.dart`)

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ClaimsProvider()),
    ChangeNotifierProvider(create: (_) => ClinicalChatProvider()),
    ChangeNotifierProvider(create: (_) => WarRoomProvider()),
    ChangeNotifierProvider(create: (_) => TicketProvider()),
    ChangeNotifierProvider(create: (_) => PreferencesProvider()),
    ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
    ChangeNotifierProvider(create: (_) => JobTrackingManager()),
  ],
  child: MaterialApp(...)
)
```

---

## 4. Providers (ViewModels)

### `AuthProvider` — Session & RBAC
**File:** `lib/providers/auth_provider.dart`

| State | Type | Description |
|---|---|---|
| `isAuthenticated` | `bool` | Whether user has a valid session |
| `currentUser` | `UserModel?` | Authenticated user object |
| `userRole` | `String?` | `'STUDENT'` or `'ADMIN'` |
| `institutionId` | `String?` | Tenant partition key |
| `isLoading` | `bool` | Auth operation in progress |

**Key methods:**
```dart
await authProvider.signIn(email, password);
await authProvider.signUp(email, password, role, institutionId);
await authProvider.signOut();
bool get isAdmin => userRole == 'ADMIN';
```

Routing logic in `main.dart` reads `isAuthenticated` and `isAdmin` to push the correct entry screen.

---

### `ClaimsProvider` — Triage Queue State
**File:** `lib/providers/claims_provider.dart`

| State | Type | Description |
|---|---|---|
| `claims` | `List<Claim>` | Filtered + sorted claim list |
| `selectedEsiFilter` | `String?` | Active ESI level filter |
| `searchQuery` | `String` | Text search filter |
| `isLoading` | `bool` | API fetch in progress |

**Key methods:**
```dart
await claimsProvider.fetchClaims(institutionId);
claimsProvider.filterByEsi('ESI_1_CRITICAL');
claimsProvider.search('fracture');
```

Sorted descending by `crisis_severity_index` after fetch.

---

### `ClinicalChatProvider` — PFA Conversation State
**File:** `lib/providers/clinical_chat_provider.dart`

| State | Type | Description |
|---|---|---|
| `messages` | `List<ChatMessage>` | Ordered conversation history |
| `isTyping` | `bool` | AI is generating a reply |
| `resources` | `List<EmergencyResource>?` | Crisis hotline cards (if crisis detected) |
| `requiresConfirmation` | `bool` | Awaiting patient consent to file ticket |

**Key methods:**
```dart
await chatProvider.sendMessage(ticketId, text, history);
chatProvider.clearConversation();
```

On crisis detection (`isCrisisResponse: true` from API), automatically surfaces the emergency resource cards overlay.

---

### `WarRoomProvider` — Admin Telemetry State
**File:** `lib/providers/war_room_provider.dart`

| State | Type | Description |
|---|---|---|
| `kpiMetrics` | `Map<String, dynamic>` | KPI counts per ESI level |
| `fundLiquidity` | `List<HealthFund>` | Fund pool balances |
| `recentDisbursements` | `List<Claim>` | Last 10 payouts |
| `alertCount` | `int` | Pending ESI-1 cases |

Refreshed every 30 seconds and on Socket.io `ticket-updated` events.

---

### `TicketProvider` — Patient-Side Ticket Tracking
**File:** `lib/providers/ticket_provider.dart`

| State | Type | Description |
|---|---|---|
| `myTickets` | `List<Claim>` | Patient's own claims |
| `activeTicket` | `Claim?` | Currently viewed claim |

---

### `JobTrackingManager` — Background Job Polling
**File:** `lib/providers/job_tracking_manager.dart`

Polls `/api/v1/intake/status/:jobId` after submission to update UI with processing progress:
- `Submitted` → `Processing` → `Triage Active` → `Approved` / `Rejected`

Uses a 2-second polling interval, cancels on terminal status.

---

## 5. Screens

### Patient Portal

#### `PatientMainScreen` — Navigation Hub
**File:** `lib/screens/patient/patient_main_screen.dart`

Bottom tab navigator with three destinations:
1. **Claim Intake** — submit a new emergency claim
2. **My Claims** — list + status tracker
3. **PFA Chat** — 24/7 counselor

---

#### `ClaimIntakeScreen` — Submit Emergency Claim
**File:** `lib/screens/patient/claim_intake_screen.dart`

**UI elements:**
- Multi-line text field for emergency description
- File picker for hospital invoice (PDF / image)
- Image picker for camera capture
- Submit button → POST `/api/v1/intake/web` (multipart)
- Real-time status feedback (submitted → processing animation)

**Validation:**
- Message text required (min 10 chars)
- Phone number format validation
- File size warning if > 10MB

---

#### `ClinicalChatScreen` — PFA Counselor Chat
**File:** `lib/screens/patient/clinical_chat_screen.dart`

**Features:**
- WhatsApp-style message bubbles (patient right, AI left)
- Typing indicator (animated dots) while `isTyping = true`
- **Crisis cards overlay:** if `isCrisisResponse = true`, slides up a card stack with emergency hotlines and `tel:` deep links
- Confirm-to-submit grant banner if `requiresConfirmation = true`
- "Take a slow breath" grounding animation on crisis response

---

#### `ClaimStatusScreen` — Copay Tracker
**File:** `lib/screens/patient/claim_status_screen.dart`

**Displays:**
- ESI level badge with color coding (red / orange / yellow / green)
- Crisis Severity Index progress bar (0.0 → 1.0)
- Fraud risk indicator (low / medium / high)
- Recommended copay amount + grant coverage %
- Payout status with transaction reference
- Step-by-step timeline: Submitted → Processing → Triage → Approved → Paid
- PDF receipt download when disbursed

---

### Admin Clinical War Room

#### `AdminMainScreen` — Navigation Hub
**File:** `lib/screens/admin/admin_main_screen.dart`

Side navigation drawer (desktop) or bottom nav (mobile) with:
1. War Room (triage queue)
2. Telemetry Dashboard
3. Health Funds
4. Knowledge Base
5. Compliance Audit

---

#### `AdminWarRoomScreen` — Real-Time Triage Queue
**File:** `lib/screens/admin/admin_war_room_screen.dart`

**Features:**
- Live claim list sorted by CSI score (descending)
- ESI color-coded row indicators
- Filter chips: All / ESI-1 / ESI-2 / ESI-3 / Routine / Flagged
- Click claim → slide-up detail sheet:
  - OCR-extracted bill amount
  - DeepRank CSI + LSTM dropout risk scores
  - Fraud flags (if any)
  - **One-tap Payout Modal:**
    - Amount field (pre-filled with `recommended_copay_amount`)
    - Method selector: UPI / Bank Transfer / Voucher
    - UPI VPA input (for UPI payouts)
    - Confirm → POST `/api/v1/admin/claims/:id/disburse`
    - Success snackbar with txn reference

Socket.io listener automatically inserts new claims at the top of the list with a brief highlight animation.

---

#### `AdminTelemetryDashboardScreen` — KPI Charts
**File:** `lib/screens/admin/admin_telemetry_dashboard_screen.dart`

**Charts (FL Chart):**
- **Donut chart:** ESI level distribution (ESI-1 / ESI-2 / ESI-3 / Routine)
- **Bar chart:** Daily claim volume (last 30 days)
- **Line chart:** Average adjudication time trend
- **Stat cards:** Total disbursed / Pending / Flagged / Fund liquidity %

---

#### `AdminHealthFundsScreen` — Fund Liquidity Management
**File:** `lib/screens/admin/admin_health_funds_screen.dart`

**Features:**
- Fund pool list with budget vs. disbursed progress bars
- Currency toggle (INR / USD)
- Top-up fund pool action (admin only)
- Historical disbursement log per fund

---

#### `AdminKnowledgeBaseScreen` — Policy RAG Search
**File:** `lib/screens/admin/admin_knowledge_base_screen.dart`

**Features:**
- Semantic search across institutional policies
- Query → POST `/api/v1/admin/knowledge/search`
- Results show matched policy name, relevance score, excerpt
- Upload new policy documents (PDF)

---

#### `AdminComplianceAuditScreen` — HIPAA Audit PDF
**File:** `lib/screens/admin/admin_compliance_audit_screen.dart`

**Features:**
- Date range picker for audit period
- Institution-scoped claim audit log preview (paginated)
- **Generate & Download PDF** → GET `/api/v1/admin/reports`
  - Streams PDF binary → saved to device downloads
- SHA-256 checksum displayed for tamper verification

---

## 6. Services (Infrastructure Layer)

### `ClinicalApiService` — REST Client
**File:** `lib/services/clinical_api_service.dart`

Wraps all HTTP calls with:
- Base URL injection from `config/`
- JWT `Authorization: Bearer` header on every request
- JSON decoding into model objects
- Timeout handling (30s default)
- Error normalization

```dart
// Example usage
final claims = await ClinicalApiService.getClaims(institutionId: id, esiLevel: 'ESI_1_CRITICAL');
final result = await ClinicalApiService.disburseClaim(claimId, amount, method, vpa);
final pdf = await ClinicalApiService.downloadAuditPdf(startDate, endDate);
```

### `SocketService` — Real-Time Events
**File:** `lib/services/socket_service.dart`

```dart
// Connect + join institution room
SocketService.connect(institutionId, token);

// Listen for updates
SocketService.onTicketUpdated.listen((event) {
  // Update ClaimsProvider state
});

SocketService.onPayoutCompleted.listen((event) {
  // Show success snackbar
});

SocketService.disconnect();
```

### `OfflineSyncManager` — Offline Fallback
**File:** `lib/services/offline_sync_manager.dart`

Uses `SharedPreferences` to:
- Cache last-fetched claims list for offline viewing
- Queue failed intake submissions for retry when connectivity returns
- Persist JWT token across app restarts

Connectivity monitoring via `connectivity_plus`.

---

## 7. Models (Domain Entities)

### `Claim`
**File:** `lib/models/claim.dart`

```dart
class Claim {
  final String id;
  final String institutionId;
  final String patientId;
  final String rawMessage;
  final String? mediaUrl;
  final String parsedCategory;
  final String esiLevel;          // 'ESI_1_CRITICAL' | 'ESI_2_EMERGENT' | ...
  final String status;            // 'Pending' | 'Processing' | 'Approved' | ...
  final double? calculatedAmount;
  final String? currency;
  final double crisisSeverityIndex;
  final double? dropoutRiskScore;
  final double? fraudRiskScore;
  final String? fraudFlags;
  final String? payoutReference;
  final String? payoutMethod;
  final DateTime createdAt;
  // fromJson / toJson
}
```

### `ClaimMessage`
```dart
class ClaimMessage {
  final String id;
  final String claimId;
  final String sender;             // 'STUDENT' | 'COUNSELOR_AI' | 'HUMAN_ADMIN'
  final String message;
  final bool isCrisisResponse;
  final List<EmergencyResource>? suggestedResources;
  final DateTime createdAt;
}
```

### `HealthFund`
```dart
class HealthFund {
  final String id;
  final String institutionId;
  final String fundName;
  final double totalBudget;
  final double allocatedAmount;
  final String currency;
  double get availableAmount => totalBudget - allocatedAmount;
  double get utilizationPercent => allocatedAmount / totalBudget;
}
```

---

## 8. Theme System (`app_theme.dart`)

**File:** `lib/theme/app_theme.dart`

### ESI Color Tokens
```dart
static const Color esiCritical = Color(0xFFDC2626);   // Red-600
static const Color esiEmergent = Color(0xFFEA580C);   // Orange-600
static const Color esiUrgent   = Color(0xFFCA8A04);   // Yellow-600
static const Color esiRoutine  = Color(0xFF16A34A);   // Green-600
```

### Clinical Color Palette
```dart
static const Color primaryBlue    = Color(0xFF1D4ED8);
static const Color surfaceDark    = Color(0xFF0F172A);
static const Color cardBackground = Color(0xFF1E293B);
static const Color textPrimary    = Color(0xFFF1F5F9);
static const Color textSecondary  = Color(0xFF94A3B8);
```

### Typography
Uses **Google Fonts Inter** (body) and **Inter Display** (headings) for clinical readability.

### ESI Badge Widget
Helper method returns themed Badge widget given ESI level string:
```dart
Widget esiLevelBadge(String esiLevel) { ... }
```

---

## 9. Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `provider` | ^6.1.5 | MVVM state management |
| `http` | ^1.6.0 | REST API calls |
| `socket_io_client` | ^3.1.6 | Real-time WebSocket events |
| `fl_chart` | ^1.2.0 | Telemetry charts |
| `google_fonts` | ^8.2.1 | Inter font family |
| `file_picker` | ^8.1.7 | Invoice PDF/image selection |
| `image_picker` | ^1.1.2 | Camera capture |
| `qr_flutter` | ^4.1.0 | QR code for voucher display |
| `url_launcher` | ^6.3.2 | `tel:` deep links for crisis hotlines |
| `connectivity_plus` | ^7.3.1 | Network state monitoring |
| `shared_preferences` | ^2.5.5 | Offline cache + token persistence |
| `flutter_local_notifications` | ^22.2.0 | Local push for status changes |
| `intl` | ^0.20.3 | Currency + date formatting |

---

## 10. Running the Flutter App

```bash
# Install dependencies
flutter pub get

# Run on default device (Chrome for web, emulator for mobile)
flutter run

# Run on specific target
flutter run -d chrome          # Web
flutter run -d android         # Android emulator
flutter run -d ios             # iOS simulator

# Build production APK
flutter build apk --release

# Build web bundle
flutter build web --release
```

### Environment Config
Create `lib/config/api_config.dart` (not committed):
```dart
const String kApiBaseUrl = 'http://localhost:3000/api/v1';
const String kWsUrl = 'http://localhost:3000';
const String kSupabaseUrl = 'https://xxxx.supabase.co';
const String kSupabaseAnonKey = 'eyJ...';
```
