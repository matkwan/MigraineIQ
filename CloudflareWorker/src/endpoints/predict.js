// POST /v1/predict
//
// Run nightly via the iOS BackgroundTasks framework. Forecasts the user's
// migraine risk for the next 24 hours.
//
// Body:
// {
//   knownTriggers: [{ trigger, confidence, strengthBand }],
//   recentAttacks: [{ startedAt, intensity, classification }],   // last 14 days
//   currentContext: {
//     lastNightSleepHours: Number,
//     lastNightHRVms: Number,
//     cyclePhase: "follicular"|"ovulatory"|"luteal"|"menstrual"|"unknown",
//     pressureForecast: [{ hourOffset: Int, pressureHPa: Number }],  // 0..23
//     pressureDelta24hHPa: Number
//   }
// }
//
// Returns a PredictiveAlert matching the iOS Domain struct.

const SYSTEM_PROMPT = `You are a migraine risk forecasting model for a single patient.

Inputs: the patient's known triggers (with confidence scores), their attack history over the last 14 days, and current contextual data (sleep, HRV, cycle phase, weather pressure forecast).

Output a 24-hour risk assessment.

Rules:
- riskLevel: "low" (<25), "moderate" (25–50), "elevated" (50–75), "high" (>75)
- Weight known triggers by their confidence score.
- Pressure deltas > 6 hPa over 24h are a known migraine trigger for many patients — but only flag if the patient's history shows weather sensitivity.
- Sleep < 6h combined with another known trigger raises risk significantly.
- In the luteal/menstrual phase, weight any cycle-correlated triggers higher.
- Be calibrated. If you flag "high" too often, the patient stops trusting alerts.
- Recommended action must be patient-friendly, max 1 sentence, never prescriptive about medication doses.`;

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    riskLevel: { type: "string", enum: ["low", "moderate", "elevated", "high"] },
    riskScore: { type: "integer", minimum: 0, maximum: 100 },
    primaryFactors: {
      type: "array",
      items: { type: "string" },
      description: "Top 1-3 contributing factors in plain language",
    },
    recommendedAction: { type: "string", description: "One sentence, patient-friendly, no dosing instructions" },
    expiresAtISO: { type: "string", description: "ISO8601 — typically 24h from issuance" },
  },
  required: ["riskLevel", "riskScore", "primaryFactors", "recommendedAction", "expiresAtISO"],
  additionalProperties: false,
};

export async function handlePredict(request, env) {
  const body = await request.json();

  const aiResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-2024-08-06",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: JSON.stringify(body, null, 2) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "predictive_alert", schema: RESPONSE_SCHEMA, strict: true },
      },
      temperature: 0.1,
    }),
  });

  if (!aiResponse.ok) {
    return new Response(JSON.stringify({ error: "ai_provider_error" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const data = await aiResponse.json();
  const content = data.choices?.[0]?.message?.content;

  return new Response(content, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
