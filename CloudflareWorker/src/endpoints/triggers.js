// POST /v1/triggers
//
// Run weekly. Computes a personal trigger model from attack history + context.
// Returns an array of TriggerInsight matching the iOS Domain struct.
//
// Body shape (matches iOS DTO):
// {
//   events: [{ id, startedAt, endedAt, intensity, classification, ... }],
//   context: {
//     sleep: [{ date, hours }],
//     hrv: [{ date, msAvg }],
//     weather: [{ date, pressureHPa, pressureDeltaHPa, humidity, temp }],
//     cycle: [{ date, phase }],
//     foodTags: [{ date, tags: [String] }]
//   }
// }

const SYSTEM_PROMPT = `You are a clinical migraine pattern analyst.

Given a patient's headache event history and contextual data (sleep, HRV, weather pressure changes, menstrual cycle phase, food tags), identify potential triggers and assign each a confidence score (0.0–1.0) based on co-occurrence frequency, statistical strength, and physiological plausibility.

Rules:
- Return only triggers with at least 3 supporting events.
- Use ICHD-3 and current migraine literature as your reference base.
- Confidence bands: 0.0–0.3 weak, 0.3–0.7 moderate, 0.7–1.0 strong.
- Be conservative — false positives cause patient anxiety. Prefer to omit a trigger than overstate it.
- Never assign confidence > 0.9 without at least 10 supporting events.
- Do NOT give medical advice. You only identify statistical correlations.`;

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    insights: {
      type: "array",
      items: {
        type: "object",
        properties: {
          trigger: { type: "string", description: "Short label, e.g. 'Barometric pressure drop' or 'Red wine'" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          occurrenceCount: { type: "integer", minimum: 3 },
          strengthBand: { type: "string", enum: ["weak", "moderate", "strong"] },
          explanation: { type: "string", description: "1-2 sentence plain-language explanation of the correlation" },
        },
        required: ["trigger", "confidence", "occurrenceCount", "strengthBand", "explanation"],
        additionalProperties: false,
      },
    },
  },
  required: ["insights"],
  additionalProperties: false,
};

export async function handleTriggers(request, env) {
  const body = await request.json();
  const userPrompt = JSON.stringify(body, null, 2);

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
        { role: "user", content: userPrompt },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "trigger_insights", schema: RESPONSE_SCHEMA, strict: true },
      },
      temperature: 0.2,
    }),
  });

  if (!aiResponse.ok) {
    const errText = await aiResponse.text();
    console.error("openai_error", errText);
    return new Response(JSON.stringify({ error: "ai_provider_error" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const data = await aiResponse.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) {
    return new Response(JSON.stringify({ error: "ai_empty_response" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  // content is already JSON-schema-validated by OpenAI; pass through.
  return new Response(content, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
