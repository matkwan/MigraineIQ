// Per-install, per-endpoint rate limiting backed by Cloudflare KV.
//
// Limits are deliberately tight on AI endpoints — these calls cost real money
// and a runaway client could burn through quota. Tune per the cost model.
//
// KV key format:  rate:<installId>:<endpoint>:<windowStart>
// KV value:        the request count in that window

const LIMITS = {
  // path -> { perMin, perDay }
  "/v1/triggers": { perMin: 2, perDay: 8 },   // weekly recompute, no need for more
  "/v1/predict":  { perMin: 4, perDay: 20 },  // typically once nightly + manual checks
  "/v1/coach":    { perMin: 10, perDay: 100 }, // chat needs more headroom
};

export async function checkRateLimit(kv, installId, path) {
  const limit = LIMITS[path];
  if (!limit) return { allowed: true };

  const now = Date.now();
  const minuteWindow = Math.floor(now / 60_000);
  const dayWindow = Math.floor(now / 86_400_000);

  const minuteKey = `rate:${installId}:${path}:m:${minuteWindow}`;
  const dayKey = `rate:${installId}:${path}:d:${dayWindow}`;

  const [minCount, dayCount] = await Promise.all([
    kv.get(minuteKey).then(v => parseInt(v || "0", 10)),
    kv.get(dayKey).then(v => parseInt(v || "0", 10)),
  ]);

  if (minCount >= limit.perMin) {
    return { allowed: false, retryAfter: 60 - Math.floor((now % 60_000) / 1000) };
  }
  if (dayCount >= limit.perDay) {
    return { allowed: false, retryAfter: 86_400 - Math.floor((now % 86_400_000) / 1000) };
  }

  // Optimistic increment. KV is eventually consistent so this can race —
  // acceptable given the low blast radius (a few extra calls). For strict
  // limits use Durable Objects instead.
  await Promise.all([
    kv.put(minuteKey, String(minCount + 1), { expirationTtl: 120 }),
    kv.put(dayKey, String(dayCount + 1), { expirationTtl: 90_000 }),
  ]);

  return { allowed: true };
}
