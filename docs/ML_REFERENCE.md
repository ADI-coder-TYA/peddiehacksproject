# MedAccess AI — ML Reference

> **Deep-dive into all machine learning models:** DeepRank ESI classifier, LSTM attrition predictor, Autoencoder fraud detector, and local Qwen2.5 PFA counselor.

---

## Overview

MedAccess AI runs **four ML models** entirely locally — no cloud inference costs, no patient data sent to external APIs.

| Model | Framework | Purpose | Input Shape |
|---|---|---|---|
| **DeepRank** | TensorFlow.js (Dense NN) | Predict Crisis Severity Index (CSI) | `[n, 4]` |
| **TemporalAttritionLSTM** | TensorFlow.js (LSTM) | Predict patient dropout risk | `[1, 4]` |
| **AnomalyAutoencoder** | TensorFlow.js (Autoencoder) | Detect anomalous claim patterns | `[n, 4]` |
| **Qwen2.5-0.5B PFA** | Xenova Transformers (ONNX) | Generate empathetic counselor replies | Text (ChatML) |

All four models share the **same 4-feature input vector:**

| Feature | Raw Source | Normalization |
|---|---|---|
| `word_count` | Token count of patient message | ÷ 500 |
| `urgent_keyword_count` | Matched urgent/medical keywords | ÷ 10 |
| `sentiment_score` | NLP sentiment (0 = negative, 1 = positive) | Already `[0, 1]` |
| `historical_ticket_count` | Past claims by same patient | ÷ 20 |

---

## 1. DeepRank — ESI Crisis Severity Classifier

**Source files:**
- Training definition: [`intellidesk_backend/src/ml/deep_rank.ts`](../intellidesk_backend/src/ml/deep_rank.ts)
- Inference service: [`intellidesk_backend/src/services/deepRankModel.ts`](../intellidesk_backend/src/services/deepRankModel.ts)

### Architecture

```
Input [4 features]
    │
    ├── Dense(64, relu) + L2(0.001)
    ├── BatchNormalization
    ├── Dropout(0.2)
    │
    ├── Dense(32, relu) + L2(0.001)
    ├── BatchNormalization
    ├── Dropout(0.2)
    │
    ├── Dense(16, relu)
    └── Dense(1, sigmoid)   ──► Crisis Severity Index ∈ [0.0, 1.0]
```

**Optimizer:** Adam (lr=0.0005)  
**Loss:** Mean Squared Error  
**Regularization:** L2(0.001) on first two dense layers + Dropout(0.2)  
**Early stopping:** patience=3 on `val_loss`

### Training
```bash
# Generate synthetic training data + train all models
npm run train:ml
```

Training data: `data/train.csv` and `data/val.csv`  
Saved weights: `models/deep_rank/model.json` + `model.weights.bin`

### ESI Mapping

| CSI Score | ESI Level | Grant Coverage | SLA |
|---|---|---|---|
| `≥ 0.85` | ESI_1_CRITICAL | 100% (up to ₹80,000) | < 2 min |
| `0.60–0.85` | ESI_2_EMERGENT | 80% (up to ₹40,000) | < 10 min |
| `0.35–0.60` | ESI_3_URGENT | 50% (up to ₹20,000) | < 30 min |
| `< 0.35` | ROUTINE | 30% (up to ₹5,000) | < 2 hrs |

Life-safety keywords (e.g., "suicid", "kill myself") force-override CSI ≥ 0.85 regardless of model output.

### Inference API
```typescript
// Single prediction
const csi: number = await predict([word_count, urgent_kw, sentiment, hist_count]);

// Batch ranking (sorts descending by CSI)
const ranked: TicketBatch[] = rankPendingQueue(ticketsArray);
```

### Online Fine-Tuning
The `mlRetrainingWorker` periodically calls `fineTuneDeepRankModel(resolvedTickets)` to update weights on real outcome data (5 epochs, batch size 32). This closes the feedback loop from adjudication decisions back into the model.

---

## 2. TemporalAttritionLSTM — Dropout Risk Predictor

**Source files:**
- Training definition: [`intellidesk_backend/src/ml/lstm.ts`](../intellidesk_backend/src/ml/lstm.ts)
- Inference service: [`intellidesk_backend/src/services/attritionModel.ts`](../intellidesk_backend/src/services/attritionModel.ts)

### Architecture

```
Input [1, 4]  (TIME_STEPS=1, FEATURES=4)
    │
    ├── LSTM(32, dropout=0.2, recurrent_dropout=0.2)
    ├── Dense(16, relu)
    └── Dense(1, sigmoid)   ──► Dropout Risk ∈ [0.0, 1.0]
```

**Optimizer:** Adam (lr=0.001)  
**Loss:** Binary Cross-Entropy  
**Epochs:** 10

### Purpose
Predicts the probability a patient will disengage from care or abandon a claim before resolution. Surfaced in the Admin War Room alongside ESI level to help prioritize outreach for at-risk patients.

### Design Note
The LSTM uses `TIME_STEPS=1` to mock time-series structure with a single static feature snapshot. True temporal modeling (multi-step sequences over visit history) is a planned enhancement.

### Inference
```typescript
import { predictAttritionRisk } from './services/attritionModel.js';
const dropoutRisk: number = await predictAttritionRisk(features);
```

---

## 3. AnomalyAutoencoder — Fraud Anomaly Detector

**Source files:**
- Training definition: [`intellidesk_backend/src/ml/autoencoder.ts`](../intellidesk_backend/src/ml/autoencoder.ts)
- Inference service: [`intellidesk_backend/src/services/anomalyModel.ts`](../intellidesk_backend/src/services/anomalyModel.ts)

### Architecture

```
Input [4 features]
    │
    ├── [Encoder]  Dense(16, relu)
    ├── [Bottleneck] Dense(4, relu)   ◄── latent space (dimensionality reduction)
    ├── [Decoder]  Dense(16, relu)
    └── [Reconstruction] Dense(4, sigmoid)
```

**Optimizer:** Adam (lr=0.001)  
**Loss:** Mean Squared Error (reconstruction loss)  
**Target:** `xs === ys` — the model learns the distribution of *normal* claims

### How Anomaly Detection Works
1. Train only on known-good (non-fraudulent) claim feature vectors
2. At inference: reconstruct the input and compute MSE between input and reconstruction
3. High reconstruction error → the input doesn't fit the learned distribution of normal claims → anomalous

```
anomaly_score = MSE(input, reconstruction)

if anomaly_score ≥ 0.75 → flag as ANOMALOUS_PATTERN
```

### Integration with Fraud Sentinel
The autoencoder is one of three fraud signals in `fraudSentinel.ts`:

```
Fraud Risk = SHA-256 Duplicate Check (+0.50)
           + 7-day Velocity Check    (+0.35)
           + Autoencoder Anomaly     (+0.40)
           + Threshold Gaming Check  (+0.30)
           ─────────────────────────────────
           Capped at 1.0

isFlagged = riskScore ≥ 0.60 (or ≥ 0.50 for life-safety cases)
```

Life-safety critical claims have reduced fraud sensitivity — only hard fraud (duplicate receipt) triggers a flag.

---

## 4. Qwen2.5-0.5B — PFA Counselor AI

**Source files:**
- Pipeline service: [`intellidesk_backend/src/services/crisisCounselorService.ts`](../intellidesk_backend/src/services/crisisCounselorService.ts)
- Alternate implementation: [`intellidesk_backend/src/services/clinicalCounselorService.ts`](../intellidesk_backend/src/services/clinicalCounselorService.ts)

### Model Loading
```typescript
// Primary: Xenova/Qwen1.5-0.5B-Chat (quantized)
// Fallback: onnx-community/Qwen2.5-0.5B-Instruct (quantized)
// Final fallback: Rogerian PFA rule engine (no model needed)

const model = await pipeline('text-generation', 'Xenova/Qwen1.5-0.5B-Chat', { quantized: true });
```

Models are loaded once and cached in-process. First load downloads ~300MB ONNX weights to the local Xenova cache directory.

### Inference Pipeline

```
Student Message
       │
       ├─ Safety Check: CRITICAL_SELF_HARM_REGEX
       │   → triggers crisis protocol + EMERGENCY_RESOURCES
       │
       ├─ Hardship Check: RELIEF_HARDSHIP_REGEX
       │   → requiresConfirmation = true → Rogerian grant offer
       │
       ├─ Multi-turn ChatML prompt build:
       │   system: MedAccess PFA system prompt
       │   + last 4 turns of conversation history
       │   + current student message
       │
       ├─ Qwen inference (max_new_tokens=45, temperature=0.6, top_p=0.85)
       │   with 2500ms safety timeout (race with timeout promise)
       │
       ├─ Output validation + disclaimer filter
       │   → fallback to generateRogerianPFAResponse() if invalid
       │
       └─ Store in ticket_messages + return to client
```

### Crisis Detection Regex
```typescript
CRITICAL_SELF_HARM_REGEX = /\b(suicid(e|al)|kill myself|end my life|self harm|
  hurt myself|want to die|overdose|cut myself|hang myself|don't want to live|
  no reason to live|end it all|better off dead|give up on life)\b/i
```

When triggered:
1. `isCrisisResponse = true` on the stored message
2. `EMERGENCY_RESOURCES` card array sent to client
3. Rogerian crisis response generated (overrides ONNX output)
4. Crisis hotline numbers appended to response

### Emergency Resource Cards

```typescript
EMERGENCY_RESOURCES = [
  { name: "Tele-MANAS (India)", number: "14416", actionUrl: "tel:14416" },
  { name: "988 Suicide & Crisis Lifeline", number: "988", actionUrl: "tel:988" },
  { name: "Vandrevala Foundation", number: "+91 9999 666 555" },
  { name: "MedAccess 24/7 Emergency Desk", number: "1800-MED-ACCESS" }
]
```

### System Prompt
The model is instructed to:
- Practice active listening and validate distress
- Keep replies to 2–4 sentences (max_new_tokens=45 enforces this)
- Use grounding techniques ("Take a slow breath with me")
- Reassure that clinical staff are actively processing their request
- Route to emergency numbers for immediate life-safety concerns

---

## 5. NLP Feature Extraction Pipeline

**Source file:** [`intellidesk_backend/src/services/nlpPipeline.ts`](../intellidesk_backend/src/services/nlpPipeline.ts)

Converts raw patient text → normalized 4-feature vector for all ML models:

```typescript
function extractFeatures(text: string, historicalCount: number): number[] {
  const word_count = text.split(/\s+/).length;
  const urgent_keyword_count = countUrgentKeywords(text);  // e.g. "emergency", "urgent", "bleeding"
  const sentiment_score = computeSentiment(text);           // 0 (negative) → 1 (positive)
  const historical_ticket_count = historicalCount;
  return [word_count, urgent_keyword_count, sentiment_score, historical_ticket_count];
}
```

---

## 6. Training Data Generation

**Source file:** [`intellidesk_backend/scripts/generate_training_data.ts`](../intellidesk_backend/scripts/)

Synthetic dataset generation creates `data/synthetic_tickets.csv` with labeled examples:
- `word_count`, `urgent_keyword_count`, `sentiment_score`, `historical_ticket_count`
- Labels: `crisis_severity_index`, `recommended_grant`, `dropout_risk`

Run with:
```bash
npm run train:ml
# Runs: generate_training_data.ts → train_all.ts
# Outputs: models/deep_rank/, models/lstm/, models/autoencoder/
```

---

## 7. Grant Optimizer Model

**Source file:** [`intellidesk_backend/src/services/grantOptimizerModel.ts`](../intellidesk_backend/src/services/grantOptimizerModel.ts)

A separate regression model that outputs `recommended_copay_amount` given:
- CSI score from DeepRank
- Fund liquidity ratio
- Institutional currency (INR / USD)
- Historical grant approval rates

Used by the admin war room to pre-populate the payout modal with a data-driven recommendation.

---

## 8. Model File Locations

```
intellidesk_backend/
├── models/
│   ├── deep_rank/
│   │   ├── model.json          # TF.js model topology
│   │   └── model.weights.bin   # Trained weights
│   ├── lstm/
│   │   ├── model.json
│   │   └── model.weights.bin
│   └── autoencoder/
│       ├── model.json
│       └── model.weights.bin
└── data/
    ├── train.csv               # DeepRank training set
    ├── val.csv                 # DeepRank validation set
    └── synthetic_tickets.csv   # LSTM + Autoencoder training set
```

> **Note:** Model weights are not committed to Git. Run `npm run train:ml` after cloning to regenerate them.
