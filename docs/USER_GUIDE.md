# MedAccess AI — User Guide

> **Real-world usage for patients, students, and clinical administrators.**  
> This guide walks through every major workflow with step-by-step instructions.

---

## Who Uses MedAccess AI?

| User | Role | Primary Goal |
|---|---|---|
| **Patient / Student** | `STUDENT` role | Submit emergency medical claims, access PFA chat, track copay status |
| **Clinical Administrator / CMO** | `ADMIN` role | Triage queue, approve disbursements, audit compliance |
| **Auditor** | `AUDITOR` role | Read-only access to audit logs and compliance reports |

---

## Scenario 1: Student Submits an Emergency Medical Claim

### Situation
Alex is a university student who was rushed to the ER with acute appendicitis. She has a hospital invoice for ₹12,500 and needs emergency copay relief immediately.

### Steps

**1. Open the MedAccess AI App**
- Launch the app on your phone or browser
- Sign in with your campus credentials

**2. Tap "Submit Emergency Claim"** (Claim Intake screen)
- You'll see a form with two fields:
  - **Describe your emergency:** Write what happened and why you need urgent financial help
  - **Attach hospital invoice:** Tap the paperclip icon to attach your hospital bill (PDF or photo)

**3. Fill in the form**
```
Emergency Description:
"I was admitted to City Hospital last night with acute appendicitis and had emergency surgery.
My bill is ₹12,500 and I cannot pay the hospital before discharge. I need emergency copay
assistance immediately."

Attached: hospital_invoice_cityhosp_aug15.pdf
```

**4. Tap "Submit Claim"**

The system will immediately:
- Show a **"Processing..."** animation
- Return a **Claim ID** (e.g., `MED-2026-0842`)
- Begin automated triage in the background

**5. Watch real-time status updates**

Within 30 seconds on the **Claim Status** screen:
- 🟡 `Submitted` → 🔵 `Triage Active`
- Your **ESI Level** appears: `ESI 2 – Emergent` (orange badge)
- **Crisis Severity Index:** `0.71 / 1.00`
- **Recommended Copay Grant:** ₹10,000 (80% coverage)
- **Estimated response time:** < 10 minutes

**6. Receive approval**

Once the admin approves:
- You get a push notification: *"Your emergency copay of ₹10,000 has been approved and sent to your UPI address"*
- The **Claim Status** screen shows:
  - ✅ `Disbursed`
  - **Transaction Reference:** `pout_abc12345`
  - **Payout Method:** UPI (instant)

> **Typical end-to-end time for ESI-2:** 8–12 minutes from submission to UPI receipt

---

## Scenario 2: Patient in Psychological Crisis Uses PFA Chat

### Situation
Rahul is experiencing severe exam stress and financial anxiety. He's feeling overwhelmed and doesn't know where to turn.

### Steps

**1. Open "Talk to Counselor"** (PFA Chat screen)

**2. Start typing**
```
Rahul: "I can't take this anymore. My rent is due, I failed two exams, and I don't
know how to keep going."
```

**3. Immediate AI response** (within 1–2 seconds):
```
Counselor AI: "I hear how much weight you are carrying right now, and everything you
are feeling makes complete sense. Take a slow breath with me—I am right here with
you. You don't have to face this alone, and university support services are actively
here for you."
```

**4. Grant assistance offer**

Since Rahul mentioned rent, the AI detects a financial hardship signal:
```
Counselor AI: "I hear how stressful this housing situation is. Would you like me to
submit an official Emergency Housing Grant ticket for university welfare review?"

[Yes, submit ticket]  [Not yet]
```

**5. Tap "Yes, submit ticket"**

An emergency welfare ticket is automatically created and routed to the admin queue — Rahul doesn't need to fill out any additional forms.

---

### Crisis Protocol (Immediate Life-Safety)

If a student types anything matching crisis keywords (e.g., *"I want to die"*, *"I can't go on"*):

**Immediate actions (< 500ms):**
1. Crisis response message displayed with grounding technique
2. Emergency resource cards slide up automatically:

```
🚨 IMMEDIATE SUPPORT AVAILABLE

📞 Tele-MANAS (India)     14416      [Call Now]
📞 988 Crisis Lifeline    988        [Call Now]
📞 Vandrevala Foundation  +91 9999 666 555  [Call Now]
🏥 MedAccess Emergency Desk  1800-MED-ACCESS  [Call Now]
```

3. The conversation is flagged `is_crisis_response: true` in the database
4. Admin war room receives a real-time alert for human follow-up

---

## Scenario 3: Clinical Administrator Processes the Triage Queue

### Situation
Dr. Chen is the Chief Medical Officer at campus health. She opens the Admin War Room each morning to clear the overnight queue.

### Steps

**1. Log in as Admin**
```
Email:    dr.chen@medaccess.ai
Password: admin123 (demo)
```

**2. Admin War Room opens**

The triage queue shows claims sorted by **Crisis Severity Index (highest first)**:

```
🔴 ESI 1 – CRITICAL    CSI: 0.91  |  Alex J.  |  ₹45,000  |  Fracture + hemorrhage
🟠 ESI 2 – Emergent    CSI: 0.71  |  Rahul S. |  ₹12,500  |  Appendicitis
🟡 ESI 3 – Urgent      CSI: 0.48  |  Priya M. |  ₹8,200   |  Severe migraine + CT scan
🟢 Routine             CSI: 0.22  |  James K. |  ₹2,100   |  Routine pharmacy refill
```

**3. Click the ESI-1 claim (Alex J.)**

A detail sheet slides up showing:
```
Patient:       Alex J.
Clinical Need: Fracture + hemorrhage (ER admission)
Bill Amount:   ₹45,000 (verified via OCR from PDF invoice)
ESI Level:     ESI_1_CRITICAL
CSI Score:     0.91  ████████████████████  91%
Dropout Risk:  0.67  ████████████░░░░░░░░  67%
Fraud Risk:    LOW (0.12) — No flags detected
Matched Policy: "Emergency Trauma & Surgical Care Policy v2.3"
```

**4. Approve and disburse**

Click **"Approve & Disburse"**:
```
Amount:         ₹36,000   (auto-filled: 80% of ₹45,000 bill)
                [Edit amount]

Payout Method:  ○ UPI (instant)   ● Bank Transfer   ○ Voucher
UPI Address:    alex.j@okaxis   [auto-filled from profile]

Clinical Notes: Verified trauma via hospital admission record

[Cancel]    [Confirm Payout ₹36,000]
```

Click **"Confirm Payout"** → RazorpayX processes the IMPS transfer instantly.

**5. Confirmation**
```
✅ Payout Successful
Transaction Reference: pout_xyz98765
₹36,000 sent via Bank Transfer (IMPS)
Fund Pool: Emergency Medical Fund — Remaining: ₹2,34,000
```

The patient's claim status updates to `Disbursed` in real time and a push notification is sent to their phone.

---

## Scenario 4: Handling a Flagged (Potential Fraud) Claim

### Situation
A claim comes in that the Fraud Sentinel has flagged for a duplicate receipt.

### What the Admin Sees

```
⚠️ FRAUD FLAG — Manual Review Required
Claim: #MED-2026-0901 | James K. | ₹4,500

Fraud Risk Score: 0.72  HIGH

Flags:
  • DUPLICATE_RECEIPT_DETECTED: This receipt image was already submitted
    on Claim #MED-2026-0789 (submitted 3 days ago)
  • PATIENT_HIGH_CLAIM_VELOCITY: 3 claims submitted in 7 days
```

### Admin Options

```
[Override: Approve as ESI-2]    [Reject Claim]    [Request Patient Clarification]
```

- **Override** → Admin adds clinical notes explaining why override is justified → logged in audit trail
- **Reject** → Claim closed, patient notified with reason
- **Request Clarification** → Auto-message sent to patient via chat

---

## Scenario 5: Generating a HIPAA Compliance Audit Report

### Situation
The hospital board requests a monthly audit report for August 2026.

### Steps

**1. Navigate to Compliance Audit** (admin sidebar)

**2. Set date range**
```
Start Date: 01 Aug 2026
End Date:   31 Aug 2026
Institution: Campus Health Medical Center
```

**3. Preview the audit log**

The screen shows a paginated table:
```
Date        | Claim ID | Patient | ESI Level | Amount  | Outcome   | Admin
2026-08-01  | MED-0810 | Alex J. | ESI-2     | ₹10,000 | Disbursed | Dr. Chen
2026-08-02  | MED-0812 | Rahul S.| Routine   | ₹2,000  | Approved  | System
2026-08-03  | MED-0815 | James K.| Flagged   | —       | Rejected  | Dr. Chen
...
```

**4. Download PDF Report**

Tap **"Generate & Download Audit PDF"** → A HIPAA-formatted PDF is generated with:
- Institution letterhead
- Complete adjudication log
- ML score transparency section (CSI, fraud scores for each claim)
- Disbursement ledger with RazorpayX/Stripe transaction references
- SHA-256 tamper-evident checksum printed at the bottom

```
Report Integrity Checksum (SHA-256):
a3f9d2c1e4b8f6a7d0e5c9b2f1a8e3d6c7b4a0f9e2d5c8b3a6f0e4d7c1b5a9
```

---

## Scenario 6: Admin Reviews Institutional Health Fund Liquidity

### Situation
Dr. Chen wants to ensure the Emergency Medical Fund won't run dry before month-end.

### Steps

**1. Navigate to Health Funds** (admin sidebar)

**2. View fund breakdown**

```
Emergency Medical Copay Fund        INR
████████████████░░░░░░░░░░░░  58% utilized
  Budget:     ₹5,00,000
  Disbursed:  ₹2,90,000
  Available:  ₹2,10,000

Pharmacy & Prescription Fund        INR
████░░░░░░░░░░░░░░░░░░░░░░░░  22% utilized
  Budget:     ₹1,00,000
  Disbursed:  ₹22,000
  Available:  ₹78,000

Mental Health Emergency Fund        INR
██████████░░░░░░░░░░░░░░░░░░  38% utilized
  Budget:     ₹2,00,000
  Disbursed:  ₹76,000
  Available:  ₹1,24,000
```

**3. View telemetry**

Navigate to **Telemetry Dashboard** for:
- ESI distribution pie chart (this month)
- Daily claim volume bar chart
- Average time-to-payout trend line
- Fraud flag rate

---

## Frequently Asked Questions

**Q: How fast does a critical (ESI-1) patient receive funds?**  
A: For ESI-1 cases with UPI, the end-to-end time from claim submission to funds in the patient's account is typically **under 2 minutes** after admin approval. The AI triage completes in ~30 seconds; the remaining time is the one-tap admin review.

**Q: What if I don't have a hospital invoice?**  
A: You can submit a plain-text description of your emergency. The system will still perform NLP-based ESI triage and flag the claim for receipt follow-up. An admin can manually enter the bill amount.

**Q: Is my medical information private?**  
A: Yes. All data is partitioned per institution with Row-Level Security at the database level. Patient data is never shared across institutions. The AI counselor (Qwen) runs **entirely locally** on the server — your messages are never sent to any external API.

**Q: What if the PFA AI gives a bad response?**  
A: The system has a multi-layer safety net:
1. Crisis keyword detection triggers the Rogerian rule engine (not AI generation) for life-safety messages
2. AI output validation filters out disclaimers, repetition, and prompt regurgitation
3. All responses are logged for admin review
4. Human admins can always intervene in any chat thread

**Q: Can I receive USD payouts?**  
A: Yes. If your institution is configured with `currency: 'USD'`, disbursements use Stripe Instant Payouts to a linked US bank account or debit card.

**Q: What is the EDU-GRANT voucher code?**  
A: If RazorpayX/Stripe APIs are unavailable (offline mode or sandbox), the system generates a digital voucher code (e.g., `EDU-GRANT-XB7K2M`) that can be redeemed at the campus finance office or hospital billing desk.

---

## Support & Emergency Contacts

| Resource | Contact |
|---|---|
| **Tele-MANAS (India, 24/7)** | `14416` or `1800-891-4416` |
| **988 Suicide & Crisis Lifeline (US, 24/7)** | `988` |
| **Vandrevala Foundation (India, 24/7)** | `+91 9999 666 555` |
| **MedAccess Emergency Desk** | `1800-MED-ACCESS` |
| **Technical Support** | `support@medaccess.ai` |
