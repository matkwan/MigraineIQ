// MigraineIQ AI Proxy — Cloudflare Worker entry point
//
// Security model (simple):
//   - Every request must carry a valid `X-App-Secret` header matching the
//     `APP_PROXY_SECRET` Worker secret. Any value mismatch returns 401.
//   - Each app install generates a UUID stored in iOS Keychain and sends it
//     as `X-Install-Id`. The worker uses this for per-install rate limiting.
//
// This is the standard shared-secret pattern. It's not as strong as App
// Attest (a leaked secret stays leaked) but it's enough to keep your AI
// quota safe from random scraping, and it works on the Simulator.

import { handleTriggers } from "./endpoints/triggers.js";
import { handlePredict } from "./endpoints/predict.js";
import { handleCoach } from "./endpoints/coach.js";
import { checkRateLimit } from "./lib/rateLimit.js";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    try {
      if (request.method === "OPTIONS") {
        return new Response(null, { status: 204, headers: corsHeaders() });
      }

      // 1. Shared-secret check (constant-time compare).
      const provided = request.headers.get("X-App-Secret") || "";
      if (!constantTimeEqual(provided, env.APP_PROXY_SECRET || "")) {
        return jsonError(401, "unauthorized");
      }

      // 2. Install ID required for rate limiting.
      const installId = request.headers.get("X-Install-Id");
      if (!installId || installId.length < 16) {
        return jsonError(400, "missing_install_id");
      }

      // 3. Per-install rate limit (skipped if RATE_KV not bound).
      if (env.RATE_KV) {
        const limit = await checkRateLimit(env.RATE_KV, installId, url.pathname);
        if (!limit.allowed) {
          return jsonError(429, "rate_limited", { retryAfter: limit.retryAfter });
        }
      }

      // 4. Route.
      switch (url.pathname) {
        case "/v1/triggers":
          return await handleTriggers(request, env);
        case "/v1/predict":
          return await handlePredict(request, env);
        case "/v1/coach":
          return await handleCoach(request, env);
        case "/v1/health":
          return new Response(JSON.stringify({ ok: true }), {
            headers: { "Content-Type": "application/json" },
          });
        default:
          return jsonError(404, "not_found");
      }
    } catch (err) {
      console.error("worker_error", err.stack || err.message);
      return jsonError(500, "internal_error");
    }
  },
};

function constantTimeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "X-App-Secret, X-Install-Id, Content-Type",
  };
}

function jsonError(status, code, extra = {}) {
  return new Response(JSON.stringify({ error: code, ...extra }), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}
