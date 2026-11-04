import { Config, Fetcher } from "../_shared/backend.ts";
import { HttpError } from "../_shared/http.ts";
import { validateSummary, validateWorksheet } from "../_shared/study_content.ts";
import { createHandler } from "../study-assistant/handler.ts";
import { validateQuiz } from "../_shared/gemini.ts";

const owner = "11111111-1111-4111-8111-111111111111";
const requestId = "22222222-2222-4222-8222-222222222222";
const documentIds = [
  "33333333-3333-4333-8333-333333333333",
  "44444444-4444-4444-8444-444444444444",
];
const quizId = "55555555-5555-4555-8555-555555555555";
const config: Config = {
  supabaseUrl: "https://example.supabase.co",
  anonKey: "public-key",
  serviceRoleKey: "server-only",
  geminiApiKey: "server-gemini",
  geminiModel: "gemini-2.5-flash",
};
const summary = {
  brief: ["Khái niệm chính"],
  sections: [{ title: "Nội dung", points: ["Kiến thức cần nhớ"] }],
  keywords: ["Định nghĩa"],
  mind_map: [{ title: "Nhánh", points: ["Ý chính"] }],
};
const output = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
function ok(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function equal(a: unknown, b: unknown) {
  ok(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`);
}
const body = (changes: Record<string, unknown> = {}) => ({
  request_id: requestId,
  kind: "summary",
  title: "Tài liệu",
  document_ids: documentIds,
  ...changes,
});
const request = (value: unknown, auth = true) =>
  new Request("https://edge.example/study-assistant", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(auth ? { Authorization: "Bearer access-token" } : {}),
    },
    body: JSON.stringify(value),
  });
function fixture(
  model: unknown = summary,
  options: { foreign?: boolean; oversized?: boolean; quota?: boolean } = {},
) {
  const calls: { url: string; body: Record<string, unknown> | null }[] = [];
  let stored: Record<string, unknown> | null = null;
  const bytes = new TextEncoder().encode("Nội dung tham khảo: định nghĩa và ví dụ.");
  const fetcher: Fetcher = async (url, init) => {
    await Promise.resolve(); // Preserve the asynchronous fetch boundary in the test double.
    const path = url.toString();
    const data = init?.body ? JSON.parse(init.body.toString()) : null;
    calls.push({ url: path, body: data });
    if (path.endsWith("/auth/v1/user")) return output({ id: owner });
    if (path.includes("/rest/v1/ai_artifacts?")) {
      equal(new URL(path).searchParams.get("owner_id"), `eq.${owner}`);
      return output(stored ? [stored] : []);
    }
    if (path.includes("/rest/v1/documents?")) {
      equal(new URL(path).searchParams.get("owner_id"), `eq.${owner}`);
      const id = new URL(path).searchParams.get("id")!.slice(3);
      return output(
        options.foreign ? [] : [{
          id,
          owner_id: owner,
          title: id,
          storage_path: `${owner}/${id}/notes.txt`,
          mime_type: "text/plain",
          size_bytes: options.oversized ? 6 * 1024 * 1024 : bytes.length,
        }],
      );
    }
    if (path.includes("/storage/v1/object/")) {
      return new Response(bytes, { headers: { "Content-Type": "text/plain" } });
    }
    if (path.endsWith("/rpc/acquire_ai_request")) {
      return options.quota ? output({ code: "P0429" }, 400) : output(requestId);
    }
    if (path.endsWith("/rpc/release_ai_request")) return new Response(null, { status: 204 });
    if (path.includes("generativelanguage.googleapis.com")) {
      return output({
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: JSON.stringify(model) }] },
        }],
      });
    }
    if (path.endsWith("/rpc/save_ai_artifact")) {
      stored = {
        id: data.p_id,
        owner_id: data.p_owner_id,
        kind: data.p_kind,
        title: data.p_title,
        document_ids: data.p_document_ids,
        source_titles: data.p_document_ids,
        content: data.p_content,
        request_fingerprint: data.p_fingerprint,
        quiz_id: data.p_kind === "quiz" ? quizId : null,
      };
      return output(stored);
    }
    throw new Error(`Unexpected ${path}`);
  };
  return { calls, fetcher };
}

Deno.test("study tools require a user token before any service calls", async () => {
  const f = fixture();
  equal((await createHandler(config, f.fetcher)(request(body(), false))).status, 401);
  equal(f.calls.length, 0);
});
Deno.test("study tools reject malformed sources, types and counts before model work", async () => {
  for (
    const changes of [
      { request_id: null },
      { kind: "unknown" },
      { document_ids: [] },
      { document_ids: [documentIds[0], documentIds[0]] },
      { document_ids: ["invalid"] },
      { kind: "quiz", topic: "Toán", question_count: 41 },
      { kind: "quiz", topic: "Toán", question_count: 10, question_kinds: ["essay"] },
      { kind: "worksheet", topic: "Toán", question_count: 10, question_kinds: [] },
    ]
  ) {
    const f = fixture();
    equal((await createHandler(config, f.fetcher)(request(body(changes)))).status, 400);
    ok(
      !f.calls.some((c) =>
        c.url.includes("generativelanguage") || c.url.includes("save_ai_artifact")
      ),
    );
  }
});
Deno.test("summary bundles only owned sources and persists validated structured content", async () => {
  const f = fixture();
  const result = await createHandler(config, f.fetcher)(request(body()));
  equal(result.status, 200);
  const model = f.calls.find((c) => c.url.includes("generativelanguage"))!;
  const prompt = JSON.stringify(model.body?.contents);
  for (const id of documentIds) ok(prompt.includes(id));
  const saved = f.calls.find((c) => c.url.endsWith("/rpc/save_ai_artifact"))!;
  equal(saved.body?.p_document_ids, documentIds);
  equal(saved.body?.p_content, summary);
  equal(f.calls.at(-1)?.url.endsWith("/rpc/release_ai_request"), true);
});
Deno.test("successful retry returns the same saved material without another model call", async () => {
  const f = fixture();
  const handler = createHandler(config, f.fetcher);
  equal((await handler(request(body()))).status, 200);
  equal((await handler(request(body()))).status, 200);
  equal(f.calls.filter((c) => c.url.includes("generativelanguage")).length, 1);
  equal(f.calls.filter((c) => c.url.includes("save_ai_artifact")).length, 1);
  equal((await handler(request(body({ title: "Changed" })))).status, 409);
  equal(f.calls.filter((c) => c.url.includes("generativelanguage")).length, 1);
});
Deno.test("foreign documents stop before downloads and generation while releasing the lease", async () => {
  const f = fixture(summary, { foreign: true });
  equal((await createHandler(config, f.fetcher)(request(body()))).status, 404);
  ok(!f.calls.some((c) => c.url.includes("/storage/") || c.url.includes("generativelanguage")));
  ok(f.calls.at(-1)!.url.includes("release_ai_request"));
});
Deno.test("aggregate source size is bounded before storage downloads", async () => {
  const f = fixture(summary, { oversized: true });
  equal((await createHandler(config, f.fetcher)(request(body()))).status, 400);
  ok(!f.calls.some((c) => c.url.includes("/storage/") || c.url.includes("generativelanguage")));
});
Deno.test("invalid structured output is never saved and the request can be retried", async () => {
  const f = fixture({ brief: [] });
  equal((await createHandler(config, f.fetcher)(request(body()))).status, 502);
  ok(!f.calls.some((c) => c.url.includes("save_ai_artifact")));
  ok(f.calls.at(-1)!.url.includes("release_ai_request"));
});
Deno.test("40 question quiz persists keys only through the service RPC, not artifact content", async () => {
  const questions = Array.from(
    { length: 40 },
    (_, i) => ({
      question: `Câu ${i + 1}?`,
      options: ["A", "B", "C", "D"],
      correct_option: 1,
      explanation: "B đúng",
    }),
  );
  const f = fixture({ questions });
  const result = await createHandler(config, f.fetcher)(
    request(
      body({
        kind: "quiz",
        topic: "Toán",
        question_count: 40,
        question_kinds: ["multiple_choice"],
        difficulty: "hard",
      }),
    ),
  );
  equal(result.status, 200);
  const json = await result.json();
  equal(json.content, {});
  equal(json.quiz_id, quizId);
  const saved = f.calls.find((c) => c.url.includes("save_ai_artifact"))!;
  equal((saved.body?.p_questions as unknown[]).length, 40);
  equal(saved.body?.p_difficulty, "hard");
});
Deno.test("worksheet validation enforces formats, answer ranges, uniqueness and requested coverage", () => {
  const items = [
    {
      kind: "multiple_choice",
      question: "Q1",
      options: ["A", "B", "C", "D"],
      correct_option: 0,
      explanation: "A",
      sample_answer: "",
      hint: "H",
    },
    {
      kind: "true_false",
      question: "Q2",
      options: ["Đúng", "Sai"],
      correct_option: 1,
      explanation: "Sai",
      sample_answer: "",
      hint: "H",
    },
    {
      kind: "essay",
      question: "Q3",
      options: [],
      correct_option: -1,
      explanation: "E",
      sample_answer: "Đáp án mẫu",
      hint: "H",
    },
  ];
  equal(
    validateWorksheet({ questions: items }, 3, ["multiple_choice", "true_false", "essay"]).questions
      .length,
    3,
  );
  for (
    const value of [{ ...items[1], correct_option: 2 }, { ...items[2], sample_answer: "" }, {
      ...items[0],
      options: ["A", "A", "C", "D"],
    }]
  ) {
    let rejected = false;
    try {
      validateWorksheet({ questions: [value] }, 1, [value.kind]);
    } catch (e) {
      rejected = e instanceof HttpError;
    }
    ok(rejected);
  }
  let rejected = false;
  try {
    validateWorksheet({ questions: [items[0]] }, 1, ["multiple_choice", "essay"]);
  } catch {
    rejected = true;
  }
  ok(rejected);
});
Deno.test("summary validation rejects empty structure and non-string metadata", () => {
  equal(validateSummary(summary), summary);
  for (
    const value of [{ ...summary, brief: [] }, { ...summary, keywords: [null] }, {
      ...summary,
      sections: [],
    }]
  ) {
    let rejected = false;
    try {
      validateSummary(value);
    } catch (e) {
      rejected = e instanceof HttpError;
    }
    ok(rejected);
  }
});

Deno.test("official quiz hints are bounded and preserved as public learning hints", () => {
  const question = {
    question: "Q?",
    options: ["A", "B", "C", "D"],
    correct_option: 0,
    explanation: "A đúng",
    hint: "Đọc kỹ dữ kiện.",
  };
  equal(validateQuiz({ questions: [question] }, 1)[0].hint, question.hint);
  let rejected = false;
  try {
    validateQuiz({ questions: [{ ...question, hint: "x".repeat(301) }] }, 1);
  } catch (e) {
    rejected = e instanceof HttpError;
  }
  ok(rejected);
});
Deno.test("study generation shares the server quota and does no work after a quota denial", async () => {
  const f = fixture(summary, { quota: true });
  equal((await createHandler(config, f.fetcher)(request(body()))).status, 429);
  ok(!f.calls.some((c) => c.url.includes("generativelanguage") || c.url.includes("/storage/")));
});
