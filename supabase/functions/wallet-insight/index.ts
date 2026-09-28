// wallet-insight: writes Velora's one-line take on a wallet.
//
// The phone sends only aggregated numbers (never notes or account names).
// Providers are tried in order: Groq, then Gemini, then OpenAI. OpenAI is
// the backup for when the other two are out of credits or tokens. The AI
// keys live only here, as function secrets.
//
// Secrets: GROQ_AI_API_KEY, GEMINI_AI_API_KEY, OPENAI_API_KEY.
// Optional: GROQ_MODEL, GEMINI_MODEL, OPENAI_MODEL.

const TIMEOUT_MS = 8000;
const MAX_CHARS = 280;

type Tone = "gentle" | "balanced" | "direct";

interface Snapshot {
  currency: string;
  net_worth_minor: number;
  account_count: number;
  allocation_percent: Record<string, number>;
  week_change_minor: number;
  month_income_minor: number;
  month_spent_minor: number;
  day_of_month: number;
  /// Days of real tracking (since joining, up to 30).
  tracked_days: number;
  /// Spending over those tracked days.
  recent_spent_minor: number;
  top_category: string | null;
}

interface Provider {
  name: string;
  key: string | undefined;
  call: (key: string, system: string, user: string) => Promise<string>;
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

const isInt = (v: unknown): v is number =>
  typeof v === "number" && Number.isSafeInteger(v);

/// Accepts only the expected shape, so nothing else reaches the AI.
function parse(body: unknown): { snapshot: Snapshot; tone: Tone } | null {
  if (typeof body !== "object" || body === null) return null;
  const { snapshot: s, tone } = body as Record<string, unknown>;
  if (tone !== "gentle" && tone !== "balanced" && tone !== "direct") {
    return null;
  }
  if (typeof s !== "object" || s === null) return null;
  const r = s as Record<string, unknown>;

  if (typeof r.currency !== "string" || !/^[A-Z]{3}$/.test(r.currency)) {
    return null;
  }
  for (
    const k of [
      "net_worth_minor",
      "account_count",
      "week_change_minor",
      "month_income_minor",
      "month_spent_minor",
      "day_of_month",
    ]
  ) {
    if (!isInt(r[k])) return null;
  }
  const alloc = r.allocation_percent;
  if (typeof alloc !== "object" || alloc === null) return null;
  const allocation: Record<string, number> = {};
  for (const [k, v] of Object.entries(alloc)) {
    if (!/^[a-zA-Z]{1,20}$/.test(k) || !isInt(v) || v < 0 || v > 100) {
      return null;
    }
    allocation[k] = v;
  }
  // Older app versions don't send these; treat them as "just started".
  const tracked = isInt(r.tracked_days) ? r.tracked_days : 1;
  const recent = isInt(r.recent_spent_minor) ? r.recent_spent_minor : 0;
  if (tracked < 1 || tracked > 30 || recent < 0) return null;

  const top = r.top_category;
  if (top !== null && top !== undefined && typeof top !== "string") {
    return null;
  }

  return {
    tone,
    snapshot: {
      currency: r.currency,
      net_worth_minor: r.net_worth_minor as number,
      account_count: r.account_count as number,
      allocation_percent: allocation,
      week_change_minor: r.week_change_minor as number,
      month_income_minor: r.month_income_minor as number,
      month_spent_minor: r.month_spent_minor as number,
      day_of_month: r.day_of_month as number,
      tracked_days: tracked,
      recent_spent_minor: recent,
      // A category name is user-editable text: keep it short and plain.
      top_category: typeof top === "string"
        ? top.replace(/[^\p{L}\p{N} &'-]/gu, "").slice(0, 40) || null
        : null,
    },
  };
}

const toneGuide: Record<Tone, string> = {
  gentle: "Warm and reassuring. Never judgmental.",
  balanced: "Friendly and practical.",
  direct: "Short, blunt and to the point. No fluff.",
};

function prompts(s: Snapshot, tone: Tone): { system: string; user: string } {
  const major = (minor: number) => (minor / 100).toFixed(2);
  const system = [
    "You are Velora, a friendly personal finance coach inside a budgeting app.",
    "Write ONE insight about the user's wallet in at most two short sentences",
    `(under ${MAX_CHARS} characters). ${toneGuide[tone]}`,
    "Use only the numbers given. Do not invent facts, give investment advice,",
    "or use emojis, markdown, quotes or greetings. Amounts are in",
    `${s.currency}; write them with the currency symbol and no decimals when`,
    "they are whole.",
    `The user has tracked their money for ${s.tracked_days} day(s), so`,
    "spending figures cover those days only, not a whole month.",
    s.tracked_days < 7
      ? "They have tracked for less than a week: do NOT estimate runway, " +
        "monthly spending or how long money will last. Say it's early and " +
        "comment on what they have (net worth, where it sits, today's " +
        "logging)."
      : "Useful angles: runway (months net worth lasts at the pace of " +
        "spending_per_month), the week's change, where the money sits, or " +
        "the top spending category.",
  ].join(" ");
  const user = JSON.stringify({
    currency: s.currency,
    net_worth: major(s.net_worth_minor),
    accounts_in_net_worth: s.account_count,
    share_by_account_type_percent: s.allocation_percent,
    change_over_last_7_days: major(s.week_change_minor),
    income_this_month: major(s.month_income_minor),
    spent_this_month_so_far: major(s.month_spent_minor),
    day_of_month: s.day_of_month,
    tracked_days: s.tracked_days,
    spent_over_tracked_days: major(s.recent_spent_minor),
    spending_per_month: s.tracked_days >= 7
      ? major(Math.round(s.recent_spent_minor * 30.44 / s.tracked_days))
      : null,
    top_spending_category: s.top_category,
  });
  return { system, user };
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
  if (!res.ok) {
    // 429 and 402 mean out of credits or rate-limited: move to the next one.
    throw new Error(`HTTP ${res.status}`);
  }
  return await res.json();
}

/// Groq and OpenAI share the chat completions format.
function chatCompletions(url: string, model: string) {
  return async (key: string, system: string, user: string) => {
    const data = await post(url, { Authorization: `Bearer ${key}` }, {
      model,
      temperature: 0.6,
      max_tokens: 120,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    });
    // deno-lint-ignore no-explicit-any
    return (data as any)?.choices?.[0]?.message?.content ?? "";
  };
}

async function gemini(key: string, system: string, user: string) {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
  const data = await post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    { "x-goog-api-key": key },
    {
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: {
        temperature: 0.6,
        maxOutputTokens: 200,
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

function clean(text: string): string {
  const t = text.replace(/[*_#`"]/g, "").replace(/\s+/g, " ").trim();
  return t.length > MAX_CHARS ? `${t.slice(0, MAX_CHARS - 1).trim()}…` : t;
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
  if (!input) return json({ error: "invalid_snapshot" }, 400);

  const { system, user } = prompts(input.snapshot, input.tone);
  for (const p of providers) {
    if (!p.key) continue;
    try {
      const insight = clean(await p.call(p.key, system, user));
      if (insight) return json({ insight, provider: p.name });
    } catch (error) {
      console.warn(`wallet-insight: ${p.name} failed: ${error}`);
    }
  }
  // The app shows its own insight when this happens.
  return json({ error: "no_provider_available" }, 503);
});
