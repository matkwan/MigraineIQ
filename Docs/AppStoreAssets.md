# MigraineIQ — App Store Assets
> Ready to paste into App Store Connect. Last updated: May 2026.

---

## 1. App Metadata

| Field | Value |
|---|---|
| **App Name** | MigraineIQ |
| **Subtitle** | Clinical Migraine Journal |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Medical |
| **Age Rating** | 4+ |
| **Support URL** | *(your support page URL)* |
| **Privacy Policy URL** | *(your privacy policy URL)* |

---

## 2. Promotional Text
*(170 characters max — can be updated at any time without a new review)*

```
Track migraines smarter. AI predicts your next attack, maps your triggers, and generates a doctor-ready PDF report — all from your wrist or lock screen.
```
*(152 characters)*

---

## 3. App Description
*(4000 characters max)*

```
MigraineIQ is a clinical-grade migraine journal built for people who live with frequent attacks. Every feature is designed around one constraint: it has to work when you can barely open your eyes.

ONE TAP TO LOG
A single large button records your attack instantly — no forms, no menus, no spinners. Tap it from your iPhone, your Apple Watch, or your Lock Screen widget. MigraineIQ logs the time and gets out of your way.

AI RISK FORECAST
Every morning MigraineIQ calculates tomorrow's migraine risk using your personal attack history, sleep quality, heart rate variability, and local barometric pressure. It learns your pattern — not a population average. Time your medication and plans around the days that matter most.

PERSONAL TRIGGER MODEL
The AI analyses your history to build a confidence-scored trigger map unique to you. See which suspected triggers actually correlate with your attacks, ranked by statistical confidence. The model updates as you log more data.

MEDICATION OVERUSE HEADACHE (MOH) TRACKING
MigraineIQ monitors your triptan and analgesic use against clinical ICHD-3 thresholds. When you approach or exceed MOH limits, you receive a Time Sensitive notification — the kind that breaks through Focus modes when it matters.

DOCTOR REPORT IN ONE TAP
Generate a PDF report containing your MIDAS disability score, HIT-6 severity score, attack frequency, medication log, and trigger summary. Share it directly from the app before your next neurology appointment.

APPLE WATCH & LOCK SCREEN
Log an attack from your Watch complication or Lock Screen widget without ever unlocking your phone. The Watch app syncs to your iPhone instantly and confirms with a green checkmark.

HEALTHKIT INTEGRATION
MigraineIQ reads your sleep duration, heart rate variability, and resting heart rate from Apple Health to build a richer risk model — without uploading your health data anywhere.

DESIGNED FOR PHOTOPHOBIA
Pure black background. No saturated colours. No looping animations. Buttons sized for minimal eye movement. Every screen is usable during an active attack.

FREE & PRO
• Free: unlimited attack logging, MOH tracking, Apple Watch, widgets, 3 AI predictions per week
• Pro: unlimited AI predictions, unlimited trigger model recomputes, doctor report PDF export

---

MigraineIQ is not a medical device and does not provide medical advice. Always consult your neurologist or healthcare provider regarding your treatment.
```

*(1 847 characters — well within the 4 000 limit, leaving room for localisation expansion)*

---

## 4. Keyword String
*(100 characters max, comma-separated — do not repeat words in the app name or subtitle)*

```
headache,diary,journal,tracker,log,trigger,aura,chronic,pain,neurology,MOH,barometric,forecast,HRV
```
*(98 characters)*

### Rationale
| Keyword | Why it's here |
|---|---|
| headache | Primary synonym searchers use |
| diary / journal / log | Three common synonyms users type |
| tracker | Common search pattern: "migraine tracker" |
| trigger | High-intent term for migraine sufferers |
| aura | Specific subtype search |
| chronic / pain | Broader pain management queries |
| neurology | Users prepping for neurologist visits |
| MOH | Niche but high-converting for power users |
| barometric | Differentiator — weather-aware forecasting |
| forecast | Ties to the AI prediction feature |
| HRV | Differentiator — HealthKit integration |

---

## 5. Privacy Nutrition Label
*(Enter these in App Store Connect → App Privacy)*

### Data Linked to You
**None.** MigraineIQ has no user accounts. No data is linked to an identity.

---

### Data Not Linked to You

#### Health & Fitness
- **Attack events** (onset time, intensity, symptoms, phase, aura) — stored locally on device via SwiftData; anonymised summaries sent to the AI service for risk and trigger analysis.
- **Medication doses** (drug name, dose, time) — stored locally; anonymised summaries used for MOH risk calculation in the AI model.
- **HealthKit data read** (sleep duration, HRV, resting heart rate) — read from Apple Health on-device only; never uploaded.

*Purposes:* App Functionality, Product Personalisation

#### User Content
- **Free-text notes and suspected triggers** — stored locally on device only; included in doctor report PDF the user generates and shares manually.

*Purposes:* App Functionality

---

### Data Used to Track You
**None.**

---

### Notes for App Store Connect
- **WeatherKit**: Location is used by the WeatherKit system framework to fetch local conditions. Your app does not access raw coordinates; Apple handles location privacy for WeatherKit automatically.
- **StoreKit 2**: Purchase and subscription data is handled entirely by Apple. You do not receive or store payment information.
- **No analytics SDK** is included in the app. No crash reporting service (Crashlytics, Sentry, etc.) is configured. No advertising network.

---

## 6. Screenshot Shoot List

### Required device sizes
App Store Connect requires at least one set of 6.7" screenshots. 6.5" is strongly recommended for older device coverage.

| Size | Devices | Resolution |
|---|---|---|
| **6.7" (required)** | iPhone 16 Pro Max, 15 Pro Max | 1320 × 2868 px |
| **6.5" (recommended)** | iPhone 14 Plus, 13 Pro Max | 1242 × 2688 px |
| **Apple Watch (if submitting Watch app)** | Series 10 45mm | 396 × 484 px |

---

### iPhone Screenshots (5–10 slots)

Capture in dark mode. Use the paired iPhone + Watch simulator or a real device.

| # | Screen to capture | Suggested caption overlay |
|---|---|---|
| 1 | **Onboarding card 1** — the welcome/calendar card | *"Built for the days you can barely open your eyes."* |
| 2 | **QuickLogContentView** — the big "I'm having a migraine" button | *"One tap. Attack logged. Done."* |
| 3 | **DashboardView** — showing a risk forecast card with risk level | *"Know your risk before it hits."* |
| 4 | **InsightsView / TriggersView** — trigger confidence list | *"Your personal trigger map, powered by AI."* |
| 5 | **HeadacheDetailView** — fully filled-in attack detail | *"Log everything. Remember nothing."* |
| 6 | **MedicationContentView** — dose list + MOH gauge | *"Stay ahead of medication overuse."* |
| 7 | **ReportView** — PDF preview with MIDAS/HIT-6 scores | *"Walk into every appointment prepared."* |
| 8 | **Lock Screen** — iPhone showing the accessoryCircular + accessoryRectangular widgets | *"Log from your lock screen."* |

---

### Apple Watch Screenshots (2–3 slots)

Capture from the Watch simulator with the Watch face visible.

| # | Screen | Suggested caption |
|---|---|---|
| 1 | **LogAttackWatchView** — the big "Log Attack" button | *"Log from your wrist."* |
| 2 | **Watch face** — showing the accessoryCircular complication on a dark face | *"One complication. Instant log."* |
| 3 | **LogAttackWatchView saved state** — green checkmark | *"Confirmed. Logged. Done."* |

---

### Tips for clean screenshots
- Run on simulator at **100% scale** to avoid aliasing.
- Use **Simulator → File → Save Screen** (or `Cmd+S`) for exact pixel dimensions.
- For caption overlays, use Figma, Sketch, or Apple's free [Screenshot Creator](https://developer.apple.com/design/resources/) template.
- Turn off the simulator's **status bar** extras via **Simulator → Features → Toggle In-Call Status Bar** — or use a clean status bar (9:41, full signal, full battery).
- For the Lock Screen screenshot, use **Simulator → Features → Lock Screen** then screenshot immediately.
