// ask-velora: Velora's chat. Answers questions about the user's money and
// turns plain-language descriptions into a suggested transaction.
//
// The phone sends the recent messages and a money summary: account names
// and balances, category names and totals. Never notes. The reply is JSON:
// { reply, action? }. An action is only a suggestion; the app shows it as a
// card and nothing is saved until the user taps "Log it".
//
// Providers are tried in order: Groq, then Gemini, then OpenAI (backup).
// Secrets: GROQ_AI_API_KEY, GEMINI_AI_API_KEY, OPENAI_API_KEY.
// Optional: GROQ_MODEL, GEMINI_MODEL, OPENAI_MODEL.

const TIMEOUT_MS = 12000;
const MAX_MESSAGES = 10;
const MAX_MESSAGE_CHARS = 500;
const MAX_CONTEXT_CHARS = 14000;
const MAX_REPLY_CHARS = 700;

type Role = "user" | "assistant";
interface Message {
  role: Role;
  content: string;
}

interface Provider {
  name: string;
  key: string | undefined;
  call: (key: string, system: string, messages: Message[]) => Promise<string>;
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/// Accepts only the expected shape and sizes.
function parse(
  body: unknown,
): { messages: Message[]; context: Record<string, unknown> } | null {
  if (typeof body !== "object" || body === null) return null;
  const { messages, context } = body as Record<string, unknown>;
  if (!Array.isArray(messages) || messages.length === 0) return null;
  if (typeof context !== "object" || context === null) return null;
  if (JSON.stringify(context).length > MAX_CONTEXT_CHARS) return null;

  const clean: Message[] = [];
  for (const m of messages.slice(-MAX_MESSAGES)) {
    if (typeof m !== "object" || m === null) return null;
    const { role, content } = m as Record<string, unknown>;
    if (role !== "user" && role !== "assistant") return null;
    if (typeof content !== "string" || content.trim().length === 0) {
      return null;
    }
    clean.push({ role, content: content.slice(0, MAX_MESSAGE_CHARS) });
  }
  if (clean[clean.length - 1].role !== "user") return null;
  return { messages: clean, context: context as Record<string, unknown> };
}

const toneGuide: Record<string, string> = {
  gentle: "Warm, encouraging and never judgmental.",
  balanced: "Friendly, clear and practical.",
  direct: "Short and blunt. No fluff.",
};

function systemPrompt(context: Record<string, unknown>): string {
  const tone = toneGuide[String(context.coach_tone)] ?? toneGuide.balanced;
  return [
    "You are Velora, a friendly red panda who is a personal finance coach",
    "inside the Velora budgeting app. Users are mostly in the Philippines",
    "and may write in English, Filipino or Taglish; reply in the language",
    `they use. ${tone}`,
    "",
    "Use ONLY the MONEY SUMMARY below for facts about the user's money.",
    "Never invent balances, transactions or numbers. If the summary can't",
    "answer, say so briefly and suggest what they could log or check.",
    "Keep replies under 3 short sentences. Format amounts with the currency",
    "symbol. No markdown, no emojis. No investment, tax or legal advice.",
    "",
    "If the user's LATEST message describes money they spent, received or",
    "moved, return an action describing it. Use an account name and a",
    "category name from the summary when one fits (otherwise null). Dates",
    "are YYYY-MM-DD relative to 'today' in the summary; omit for today.",
    "Never say you saved or logged anything: the user confirms it in the",
    "app. Say something like 'Here's what I'll log' instead.",
    "Only return an action for a new transaction, never for a question.",
    "",
    "Reply with JSON only, exactly this shape:",
    '{"reply": string, "action": null | {"kind": "expense" | "income" |',
    '"transfer", "amount": number, "account": string | null,',
    '"to_account": string | null, "category": string | null,',
    '"note": string | null, "date": string | null}}',
    "",
    "MONEY SUMMARY:",
    JSON.stringify(context),
  ].join("\n");
}

async function post(
  url: string,
  headers: Record<string, string>,
  body: unknown,
): Promise<Record<string, unknown>> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  // 429 and 402 mean out of credits or rate-limited: move to the next one.
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return await res.json();
}

/// Groq and OpenAI share the chat completions format and JSON mode.
function chatCompletions(url: string, model: string) {
  return async (key: string, system: string, messages: Message[]) => {
    const data = await post(url, { Authorization: `Bearer ${key}` }, {
      model,
      temperature: 0.3,
      max_tokens: 400,
      response_format: { type: "json_object" },
      messages: [{ role: "system", content: system }, ...messages],
    });
    // deno-lint-ignore no-explicit-any
    return (data as any)?.choices?.[0]?.message?.content ?? "";
  };
}

async function gemini(key: string, system: string, messages: Message[]) {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
  const data = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    { "x-goog-api-key": key },
    {
      systemInstruction: { parts: [{ text: system }] },
      contents: messages.map((m) => ({
        role: m.role === "assistant" ? "model" : "user",
        parts: [{ text: m.content }],
      })),
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 500,
        responseMimeType: "application/json",
        thinkingConfig: { thinkingBudget: 0 },
      },
    },
  );
  // deno-lint-ignore no-explicit-any
  const parts = (data as any)?.candidates?.[0]?.content?.parts ?? [];
  return parts.map((p: { text?: string }) => p.text ?? "").join("");
}

const providers: Provider[] = [
  {
    name: "groq",
    key: Deno.env.get("GROQ_AI_API_KEY"),
    call: chatCompletions(
      "https://api.groq.com/openai/v1/chat/completions",
      Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile",
    ),
  },
  { name: "gemini", key: Deno.env.get("GEMINI_AI_API_KEY"), call: gemini },
  {
    name: "openai",
    key: Deno.env.get("OPENAI_API_KEY"),
    call: chatCompletions(
      "https://api.openai.com/v1/chat/completions",
      Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
    ),
  },
];

/// Keeps only a well-formed reply and action.
function shape(raw: string): { reply: string; action: unknown } | null {
  let parsed: unknown;
  try {
    // Some models wrap JSON in a code fence.
    parsed = JSON.parse(raw.replace(/^```(?:json)?\s*|\s*```$/g, ""));
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) return null;
  const { reply, action } = parsed as Record<string, unknown>;
  if (typeof reply !== "string" || reply.trim().length === 0) return null;
  const text = reply.replace(/[*_#`]/g, "").trim().slice(0, MAX_REPLY_CHARS);

  let cleanAction: unknown = null;
  if (typeof action === "object" && action !== null) {
    const a = action as Record<string, unknown>;
    const amount = typeof a.amount === "string" ? Number(a.amount) : a.amount;
    const str = (v: unknown, max: number) =>
      typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null;
    if (
      (a.kind === "expense" || a.kind === "income" || a.kind === "transfer") &&
      typeof amount === "number" && amount > 0 && amount < 1e10
    ) {
      const date = str(a.date, 10);
      cleanAction = {
        kind: a.kind,
        amount,
        account: str(a.account, 40),
        to_account: str(a.to_account, 40),
        category: str(a.category, 30),
        note: str(a.note, 60),
        date: date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : null,
      };
    }
  }
  return { reply: text, action: cleanAction };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const input = parse(body);
  if (!input) return json({ error: "invalid_request" }, 400);

  const system = systemPrompt(input.context);
  for (const p of providers) {
    if (!p.key) continue;
    try {
      const out = shape(await p.call(p.key, system, input.messages));
      if (out) return json({ ...out, provider: p.name });
      console.warn(`ask-velora: ${p.name} returned an unusable reply`);
    } catch (error) {
      console.warn(`ask-velora: ${p.name} failed: ${error}`);
    }
  }
  // The app falls back to what it can answer on the phone.
  return json({ error: "no_provider_available" }, 503);
});
