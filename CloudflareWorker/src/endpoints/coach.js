// POST /v1/coach
//
// Streaming chat endpoint. The user asks a natural-language question; the AI
// answers using ONLY the 72-hour context the iOS app passes in, with citations
// back to specific data points so the answer is auditable.
//
// Body:
// {
//   question: "Why did I get a migraine yesterday?",
//   context: {
//     attacks: [...],          // last 7 days
//     doses: [...],            // last 7 days
//     sleep: [...],            // last 7 days, daily hours
//     weather: [...],          // last 72h, hourly pressure + humidity + temp
//     cycle: { phase, day },
//     foodTags: [...]          // last 72h
//   },
//   conversationHistory: [{ role, content }]   // optional, last 10 turns
// }
//
// Returns: text/event-stream of SSE chunks compatible with iOS AsyncSequence.

const SYSTEM_PROMPT = `You are a compassionate, evidence-based migraine coach.

Rules — non-negotiable:
1. Answer using ONLY the data in the user's context. Cite specific data points (e.g. "your sleep was 4.5h on Tuesday, and you logged red wine the same evening").
2. If the data is insufficient to answer, say so directly. Do not speculate.
3. Never give medical advice. Never recommend specific medications, doses, or changes to prescribed treatment. Defer treatment decisions to the patient's neurologist.
4. If the user describes a new or severe symptom (sudden onset thunderclap headache, fever + headache, neurological deficit, vision loss, weakness), tell them clearly to seek immediate medical care.
5. Be warm, brief, and specific. No platitudes. No "I'm here for you" filler.
6. Maximum 4 short paragraphs.
7. End with one suggested follow-up question the user could ask.`;

export async function handleCoach(request, env) {
  const body = await request.json();
  if (!body?.question) {
    return new Response(JSON.stringify({ error: "missing_question" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    ...(body.conversationHistory || []),
    {
      role: "user",
      content: `My personal data (last 7 days):\n${JSON.stringify(body.context, null, 2)}\n\nQuestion: ${body.question}`,
    },
  ];

  const upstream = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o",
      messages,
      stream: true,
      temperature: 0.4,
    }),
  });

  if (!upstream.ok || !upstream.body) {
    return new Response(JSON.stringify({ error: "ai_provider_error" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Forward the SSE stream straight to the client. The iOS side parses
  // `data: {...}\n\n` chunks and surfaces tokens as an AsyncThrowingStream.
  return new Response(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive",
    },
  });
}
