# MigraineIQ AI Proxy — Setup

End-to-end deployment of the Cloudflare Worker that fronts all AI calls for
the iOS app. Auth is a simple shared secret — works on the Simulator with no
real device required.

## Prerequisites

- Node.js 18+ installed locally
- A Cloudflare account (free Workers plan is fine for dev; paid for production)
- An OpenAI API key with GPT-4o access

## 1. Install wrangler

```bash
cd CloudflareWorker
npm install
npx wrangler login
```

## 2. Create the rate-limit KV namespace

```bash
npx wrangler kv namespace create RATE_KV
```

Wrangler prints something like:
```
{ binding = "RATE_KV", id = "abc123def456..." }
```
Copy the `id` into `wrangler.toml` under `[[kv_namespaces]]`.

## 3. Set the worker secrets

```bash
# Your OpenAI API key
npx wrangler secret put OPENAI_API_KEY
# Paste the key when prompted.

# A 32-byte random hex secret shared between worker and app.
# Generate it once and use the SAME value on both sides.
SECRET=$(openssl rand -hex 32)
echo "$SECRET"      # copy this — you'll paste into Config.xcconfig too
echo "$SECRET" | npx wrangler secret put APP_PROXY_SECRET
```

Save the printed `$SECRET` — you'll need it again in step 6.

## 4. Set your Cloudflare account ID

```bash
npx wrangler whoami     # prints your account_id
```
Paste it into `wrangler.toml` `account_id = "..."`.

## 5. Deploy

```bash
npx wrangler deploy
```

Wrangler prints the worker URL — something like
`https://migraineiq-ai-proxy.<your-account>.workers.dev`. Save it.

Smoke-test from your terminal (works without the iOS app):

```bash
curl -i -X POST "https://<your-worker>.workers.dev/v1/health" \
  -H "X-App-Secret: $SECRET" \
  -H "X-Install-Id: smoketest-12345678"
# Expect: HTTP/1.1 200 OK and {"ok":true}
```

If `401`, your `X-App-Secret` doesn't match the worker secret.
If `404`, the path is wrong (only `/v1/triggers`, `/v1/predict`, `/v1/coach`,
`/v1/health` are wired).

Optional second smoke test against the actual prediction endpoint:

```bash
curl -X POST "https://<your-worker>.workers.dev/v1/predict" \
  -H "X-App-Secret: $SECRET" \
  -H "X-Install-Id: smoketest-12345678" \
  -H "Content-Type: application/json" \
  -d '{
    "knownTriggers": [],
    "recentAttacks": [],
    "currentContext": {
      "lastNightSleepHours": 5.5,
      "lastNightHRVms": 28,
      "cyclePhase": "luteal",
      "pressureForecast": [
        {"hourOffset": 0, "pressureHPa": 1015},
        {"hourOffset": 12, "pressureHPa": 1006}
      ],
      "pressureDelta24hHPa": -9
    }
  }'
```

You should get back a JSON `PredictiveAlertDTO` within ~3 seconds.

## 6. Wire up the iOS side

1. Copy `Config.xcconfig.template` to `Config.xcconfig` (in the repo root).
2. Set `APP_PROXY_URL = https:/$()/<your-worker-url>` (note the `$()` xcconfig hack to escape `//`).
3. Set `APP_PROXY_SECRET = <the same $SECRET value from step 3>`.
4. In Xcode: select the project → Info tab → Configurations → set both Debug
   and Release to use `Config.xcconfig`.
5. In `Info.plist`, add two keys:
   - `APP_PROXY_URL` with value `$(APP_PROXY_URL)`
   - `APP_PROXY_SECRET` with value `$(APP_PROXY_SECRET)`
6. Verify `Config.xcconfig` is in the repo's `.gitignore` (it already is —
   double-check after `git status`).

## 7. Test from the Simulator

Build and run on any iPhone Simulator. From any view:

```swift
Task {
    do {
        let service = try AIProxyService()
        let alert = try await service.predictNext24h(.init(
            knownTriggers: [],
            recentAttacks: [],
            currentContext: .init(
                lastNightSleepHours: 5.5,
                lastNightHRVms: 28,
                cyclePhase: "luteal",
                pressureForecast: [
                    .init(hourOffset: 0, pressureHPa: 1015),
                    .init(hourOffset: 12, pressureHPa: 1006),
                ],
                pressureDelta24hHPa: -9
            )
        ))
        print("Risk: \(alert.riskLevel) (\(alert.riskScore))")
        print("Factors: \(alert.primaryFactors)")
    } catch {
        print("Error: \(error)")
    }
}
```

In a separate terminal, watch the worker logs:

```bash
npx wrangler tail
```

You should see the request appear, the OpenAI call go out, and the response
log in real time.

## 8. Common issues

- **`missingConfig` Swift error** — `APP_PROXY_URL` or `APP_PROXY_SECRET` is
  not set in `Info.plist`. Re-do step 6.
- **`401 unauthorized`** — the secret in `Config.xcconfig` doesn't match the
  worker secret. Reset by re-running step 3 then step 6.
- **`429 rate_limited`** — you've hit the per-install limits in
  `lib/rateLimit.js`. Default is 4 predict calls/min. Bump if needed.
- **`502 ai_provider_error`** — wrap `npx wrangler tail` to see the OpenAI
  error. Usually a missing/invalid `OPENAI_API_KEY` or your account hit a
  quota.
- **Worker URL returns Cloudflare's default page** — `npx wrangler deploy`
  failed silently. Re-run and check for errors.

## 9. Secret rotation

Rotate `APP_PROXY_SECRET` whenever a team member leaves or you suspect a leak:

```bash
SECRET=$(openssl rand -hex 32)
echo "$SECRET" | npx wrangler secret put APP_PROXY_SECRET
# Then update Config.xcconfig with the new value, ship a new build.
```

Note: every install of the old build stops working until they update. Plan
rotations during low-traffic windows.

Rotate `OPENAI_API_KEY` whenever an OpenAI key is exposed:

```bash
npx wrangler secret put OPENAI_API_KEY
# No client update needed.
```

## 10. Production checklist

- [ ] Rate limits in `lib/rateLimit.js` reviewed for production scale
- [ ] Cloudflare Workers paid plan enabled if expecting >100k requests/day
- [ ] `head_sampling_rate` in wrangler.toml lowered from 1.0 to ~0.1
- [ ] OpenAI account has a monthly spend limit set
- [ ] Privacy policy mentions: AI processing happens on Cloudflare + OpenAI;
      personal data sent for processing; data not used for model training
      (OpenAI API has data-not-used-for-training default — verify annually)

## Architecture reference

```
iOS app
  │  Headers on every call:
  │    X-App-Secret: <shared secret from Info.plist>
  │    X-Install-Id: <UUID from Keychain>
  │
  │  POST /v1/triggers      ←── weekly trigger model recompute
  │  POST /v1/predict       ←── nightly + manual risk check
  │  POST /v1/coach         ←── chat (SSE stream)
  │  POST /v1/health        ←── liveness check
  ▼
Cloudflare Worker (this project)
  ├── Constant-time secret compare
  ├── Per-install rate limit (KV)
  └── Forward to OpenAI Chat Completions API
        (with system prompt + JSON-schema response format)
  ▼
OpenAI GPT-4o
```

## Cost rough estimate

At ~1,000 active users:
- Cloudflare Workers: $5/mo (paid plan covers 10M requests)
- OpenAI usage:
  - `/triggers` 1×/week × 1k users × ~3k tokens × $0.0025/1k = **$30/mo**
  - `/predict`  1×/day × 1k users × ~1k tokens × $0.0025/1k = **$75/mo**
  - `/coach`    ~5×/day × 200 users × ~2k tokens × $0.0025/1k = **$75/mo**
- **Total ≈ $185/mo at 1k users.**

Comfortably covered by ~25 paying subscribers at $7.99/mo.
