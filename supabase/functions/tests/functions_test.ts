import { Backend, Config, Fetcher, timedFetch } from "../_shared/backend.ts";
import { validateQuiz } from "../_shared/gemini.ts";
import { HttpError, readBody } from "../_shared/http.ts";
import { createHandler as chatHandler } from "../ai-chat/handler.ts";
import { createHandler as quizHandler } from "../generate-quiz/handler.ts";

const owner = "11111111-1111-4111-8111-111111111111";
const threadId = "22222222-2222-4222-8222-222222222222";
const documentId = "33333333-3333-4333-8333-333333333333";
const leaseId = "44444444-4444-4444-8444-444444444444";
const quizId = "55555555-5555-4555-8555-555555555555";
const config: Config = {
  supabaseUrl: "https://example.supabase.co",
  anonKey: "public-key",
  serviceRoleKey: "server-only-key",
  geminiApiKey: "gemini-server-only",
  geminiModel: "gemini-2.5-flash",
};
const output = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
const question = {
  question: "2 + 2 bằng bao nhiêu?",
  options: ["1", "2", "3", "4"],
  correct_option: 3,
  explanation: "2 cộng 2 bằng 4.",
};
function equal(actual: unknown, expected: unknown, label = "values differ") {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${label}: ${JSON.stringify(actual)} !== ${JSON.stringify(expected)}`);
  }
}
function ok(value: unknown, label = "assertion failed"): asserts value {
  if (!value) throw new Error(label);
}
async function rejects(action: () => unknown | Promise<unknown>, code: string) {
  try {
    await action();
  } catch (error) {
    ok(error instanceof HttpError);
    equal(error.code, code);
    return;
  }
  throw new Error(`Expected HttpError ${code}`);
}
const request = (body: unknown, auth = true) =>
  new Request("https://edge.example/function", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(auth ? { authorization: "Bearer user-access-token" } : {}),
    },
    body: JSON.stringify(body),
  });
interface Call {
  url: string;
  body: Record<string, unknown> | null;
  headers: Headers;
}
type Route = (call: Call) => Response | Promise<Response> | undefined;
function fakeFetch(route?: Route) {
  const calls: Call[] = [];
  const fetcher: Fetcher = async (input, init) => {
    const call: Call = {
      url: input.toString(),
      body: init?.body ? JSON.parse(init.body.toString()) : null,
      headers: new Headers(init?.headers),
    };
    calls.push(call);
    const custom = await route?.(call);
    if (custom) return custom;
    if (call.url.endsWith("/auth/v1/user")) return output({ id: owner });
    if (call.url.endsWith("/rpc/acquire_ai_request")) return output(leaseId);
    if (call.url.endsWith("/rpc/release_ai_request")) return new Response(null, { status: 204 });
    if (call.url.includes("/rest/v1/chat_threads?")) {
      return output([{ id: threadId, owner_id: owner, document_id: null, mode: "qa" }]);
    }
    if (call.url.includes("/rest/v1/chat_messages?")) return output([]);
    if (call.url.includes("generativelanguage.googleapis.com")) {
      return output({
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: "Hãy ôn từng khái niệm và làm ví dụ." }] },
        }],
      });
    }
    if (call.url.endsWith("/rpc/save_chat_turn")) {
      return output({
        thread_id: call.body?.p_thread_id ?? threadId,
        user_message: { id: crypto.randomUUID(), role: "user", content: call.body?.p_user_content },
        assistant_message: {
          id: crypto.randomUUID(),
          role: "assistant",
          content: call.body?.p_assistant_content,
        },
      });
    }
    if (call.url.endsWith("/rpc/create_generated_quiz")) return output({ quiz_id: quizId });
    throw new Error(`Unexpected request ${call.url}`);
  };
  return { fetcher, calls };
}

Deno.test("CORS preflight and unsupported methods do not call services", async () => {
  const { fetcher, calls } = fakeFetch();
  const handler = chatHandler(config, fetcher);
  equal((await handler(new Request("https://example.test", { method: "OPTIONS" }))).status, 204);
  equal((await handler(new Request("https://example.test"))).status, 405);
  equal(calls.length, 0);
});

Deno.test("both endpoints require a user JWT, without service-side work", async () => {
  for (const factory of [chatHandler, quizHandler]) {
    const { fetcher, calls } = fakeFetch();
    equal((await factory(config, fetcher)(request({ message: "Hi" }, false))).status, 401);
    equal(calls.length, 0);
  }
});

Deno.test("expired JWT is rejected before reading any user data", async () => {
  const { fetcher, calls } = fakeFetch((call) =>
    call.url.endsWith("/auth/v1/user") ? output({}, 401) : undefined
  );
  equal((await chatHandler(config, fetcher)(request({ message: "Học toán" }))).status, 401);
  equal(calls.length, 1);
  equal(calls[0].headers.get("authorization"), "Bearer user-access-token");
  equal(calls[0].headers.get("apikey"), "public-key");
});

Deno.test("reject empty/oversized input, invalid IDs and invalid modes", async () => {
  for (
    const body of [
      { message: " " },
      { message: "x".repeat(8001) },
      { message: "ok", thread_id: "x)or(owner_id.not.is.null" },
      { message: "ok", mode: "system" },
      { message: "ok", document_id: "not-a-uuid" },
    ]
  ) {
    const { fetcher, calls } = fakeFetch();
    equal((await chatHandler(config, fetcher)(request(body))).status, 400);
    equal(calls.length, 1);
  }
});

Deno.test("streamed JSON enforces actual byte count, not Content-Length", async () => {
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode('{"message":"'));
      controller.enqueue(new Uint8Array(17000).fill(120));
      controller.close();
    },
  });
  await rejects(() =>
    readBody(
      new Request("https://example.test", {
        method: "POST",
        headers: { "content-type": "application/json", "content-length": "10" },
        body: stream,
      }),
    ), "request_too_large");
});

Deno.test("non-JSON and array bodies are rejected", async () => {
  await rejects(
    () => readBody(new Request("https://example.test", { method: "POST", body: "{}" })),
    "invalid_content_type",
  );
  await rejects(() => readBody(request([])), "invalid_body");
});

Deno.test("owned thread lookup includes authenticated owner, foreign thread is hidden", async () => {
  const { fetcher, calls } = fakeFetch((call) =>
    call.url.includes("/chat_threads?") ? output([]) : undefined
  );
  equal(
    (await chatHandler(config, fetcher)(request({ thread_id: threadId, message: "Xin chào" })))
      .status,
    404,
  );
  const lookup = new URL(calls[1].url);
  equal(lookup.searchParams.get("owner_id"), `eq.${owner}`);
  equal(calls.filter((c) => c.url.includes("generativelanguage")).length, 0);
});

Deno.test("existing thread mode/document cannot be changed", async () => {
  const { fetcher } = fakeFetch();
  equal(
    (await chatHandler(config, fetcher)(
      request({ thread_id: threadId, mode: "summary", message: "Tóm tắt" }),
    )).status,
    409,
  );
});

Deno.test("successful chat persists both sides atomically after Gemini and releases lease", async () => {
  const { fetcher, calls } = fakeFetch();
  const response = await chatHandler(config, fetcher)(
    request({ message: "  Làm sao học tốt?  ", mode: "plan" }),
  );
  equal(response.status, 200);
  const result = await response.json();
  equal(result.thread_id, threadId);
  equal(result.user_message.content, "Làm sao học tốt?");
  equal(result.assistant_message.role, "assistant");
  const gemini = calls.findIndex((c) => c.url.includes("generativelanguage"));
  const persist = calls.findIndex((c) => c.url.endsWith("save_chat_turn"));
  ok(gemini > 0 && persist > gemini);
  equal(calls[persist].body?.p_owner_id, owner);
  equal(calls[persist].body?.p_thread_id, null);
  equal(calls[persist].headers.get("authorization"), `Bearer ${config.serviceRoleKey}`);
  equal(calls[gemini].headers.get("x-goog-api-key"), config.geminiApiKey);
  ok(!calls[gemini].url.includes(config.geminiApiKey));
  equal(calls.at(-1)?.body, { p_request_id: leaseId });
  const responseText = JSON.stringify(result);
  ok(!responseText.includes(config.geminiApiKey) && !responseText.includes(config.serviceRoleKey));
});

Deno.test("Gemini failure does not persist half a turn and still releases lease", async () => {
  const { fetcher, calls } = fakeFetch((c) =>
    c.url.includes("generativelanguage")
      ? output({ error: "secret-upstream-debug" }, 500)
      : undefined
  );
  const response = await chatHandler(config, fetcher)(request({ message: "Giải thích" }));
  equal(response.status, 502);
  ok(!(await response.text()).includes("secret-upstream-debug"));
  equal(calls.filter((c) => c.url.endsWith("save_chat_turn")).length, 0);
  ok(calls.at(-1)?.url.endsWith("release_ai_request"));
});

Deno.test("Gemini safety or truncated responses do not persist", async () => {
  for (const reason of ["SAFETY", "MAX_TOKENS"]) {
    const { fetcher, calls } = fakeFetch((c) =>
      c.url.includes("generativelanguage")
        ? output({ candidates: [{ finishReason: reason }] })
        : undefined
    );
    equal((await chatHandler(config, fetcher)(request({ message: "Câu hỏi" }))).status, 502);
    equal(calls.filter((c) => c.url.endsWith("save_chat_turn")).length, 0);
  }
});

Deno.test("database quota and concurrent-thread errors map to safe HTTP statuses", async () => {
  for (const [code, status] of [["P0429", 429], ["P0409", 409]] as const) {
    const { fetcher, calls } = fakeFetch((c) =>
      c.url.endsWith("acquire_ai_request")
        ? output({ code, message: "db internals" }, 400)
        : undefined
    );
    const response = await chatHandler(config, fetcher)(request({ message: "Hello" }));
    equal(response.status, status);
    ok(!(await response.text()).includes("db internals"));
    equal(calls.filter((c) => c.url.includes("generativelanguage")).length, 0);
  }
});

Deno.test("history stays chronological, bounded and starts with user", async () => {
  const rows = Array.from(
    { length: 20 },
    (_, i) => ({ role: i % 2 === 0 ? "assistant" : "user", content: `${i}:` + "x".repeat(4000) }),
  );
  const { fetcher, calls } = fakeFetch((c) =>
    c.url.includes("/chat_messages?") ? output(rows) : undefined
  );
  const history = await new Backend(config, fetcher).history(threadId, owner);
  ok(history.length < 20);
  equal(history[0].role, "user");
  equal(history.at(-1)?.role, "assistant");
  ok(history.reduce((n, m) => n + m.content.length, 0) <= 40000);
  equal(new URL(calls[0].url).searchParams.get("limit"), "20");
});

Deno.test("document lookup uses ownership, not a supplied storage path", async () => {
  const { fetcher, calls } = fakeFetch((c) =>
    c.url.includes("/documents?") ? output([]) : undefined
  );
  const response = await chatHandler(config, fetcher)(
    request({ message: "Tóm tắt", document_id: documentId, storage_path: "foreign/private.pdf" }),
  );
  equal(response.status, 404);
  const lookup = calls.find((c) => c.url.includes("/documents?"));
  ok(lookup);
  equal(new URL(lookup.url).searchParams.get("owner_id"), `eq.${owner}`);
  equal(calls.filter((c) => c.url.includes("/storage/")).length, 0);
});

Deno.test("invalid document metadata/path cannot download arbitrary storage objects", async () => {
  for (
    const path of [
      `${owner}/../private.pdf`,
      `${owner}/${documentId}/..`,
      `${owner}/${documentId}/%252fsecret.pdf`,
      `${owner}/${documentId}/bad\\path.pdf`,
      `${owner}/${documentId}/bad?path.pdf`,
    ]
  ) {
    const { fetcher, calls } = fakeFetch((c) =>
      c.url.includes("/documents?")
        ? output([{
          id: documentId,
          owner_id: owner,
          title: "Bad",
          storage_path: path,
          mime_type: "application/pdf",
          size_bytes: 100,
        }])
        : undefined
    );
    await rejects(
      () => new Backend(config, fetcher).documentParts(documentId, owner),
      "invalid_document",
    );
    equal(calls.length, 1);
  }
});

Deno.test("PDF content is validated and sent as inline Gemini data without public URL", async () => {
  const pdf = new TextEncoder().encode("%PDF-1.7\nexample\n%%EOF");
  const { fetcher, calls } = fakeFetch((c) => {
    if (c.url.includes("/documents?")) {
      return output([{
        id: documentId,
        owner_id: owner,
        title: "Bài học",
        storage_path: `${owner}/${documentId}/lesson.pdf`,
        mime_type: "application/pdf",
        size_bytes: pdf.length,
      }]);
    }
    if (c.url.includes("/storage/")) return new Response(pdf);
  });
  const response = await chatHandler(config, fetcher)(
    request({ message: "Tóm tắt", document_id: documentId, mode: "summary" }),
  );
  equal(response.status, 200);
  const gemini = calls.find((c) => c.url.includes("generativelanguage"));
  ok(gemini);
  const contents = gemini.body?.contents as { parts: Record<string, unknown>[] }[];
  equal(contents.at(-1)?.parts[1], {
    inlineData: { mimeType: "application/pdf", data: btoa(new TextDecoder().decode(pdf)) },
  });
});

Deno.test("document size mismatch fails before sending private content to AI", async () => {
  const { fetcher } = fakeFetch((c) => {
    if (c.url.includes("/documents?")) {
      return output([{
        id: documentId,
        owner_id: owner,
        title: "Bài học",
        storage_path: `${owner}/${documentId}/lesson.txt`,
        mime_type: "text/plain",
        size_bytes: 3,
      }]);
    }
    if (c.url.includes("/storage/")) return new Response("longer content");
  });
  await rejects(
    () => new Backend(config, fetcher).documentParts(documentId, owner),
    "invalid_document",
  );
});

Deno.test("quiz accepts only integer counts from 1 to 30", async () => {
  for (const count of [0, 31, 1.5, "5", null]) {
    const { fetcher, calls } = fakeFetch();
    equal(
      (await quizHandler(config, fetcher)(
        request({ title: "Toán", topic: "Số học", question_count: count }),
      )).status,
      400,
    );
    equal(calls.length, 1);
  }
});

Deno.test("successful quiz validates AI schema then stores answer keys only in service RPC", async () => {
  const { fetcher, calls } = fakeFetch((c) =>
    c.url.includes("generativelanguage")
      ? output({
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: JSON.stringify({ questions: [question] }) }] },
        }],
      })
      : undefined
  );
  const response = await quizHandler(config, fetcher)(
    request({ title: "Toán", topic: "Số học", question_count: 1 }),
  );
  equal(response.status, 200);
  equal(await response.json(), { quiz_id: quizId });
  const persist = calls.find((c) => c.url.endsWith("create_generated_quiz"));
  ok(persist);
  equal(persist.body?.p_questions, [question]);
  equal(persist.body?.p_owner_id, owner);
  const gemini = calls.find((c) => c.url.includes("generativelanguage"));
  equal(
    (gemini?.body?.generationConfig as Record<string, unknown>).responseMimeType,
    "application/json",
  );
});

Deno.test("invalid quiz output is never persisted", async () => {
  for (
    const bad of [{ questions: [] }, { questions: [{ ...question, correct_option: 4 }] }, {
      questions: [{ ...question, options: ["a", "a", "b", "c"] }],
    }]
  ) {
    const { fetcher, calls } = fakeFetch((c) =>
      c.url.includes("generativelanguage")
        ? output({
          candidates: [{
            finishReason: "STOP",
            content: { parts: [{ text: JSON.stringify(bad) }] },
          }],
        })
        : undefined
    );
    equal(
      (await quizHandler(config, fetcher)(
        request({ title: "Quiz", topic: "Math", question_count: 1 }),
      )).status,
      502,
    );
    equal(calls.filter((c) => c.url.endsWith("create_generated_quiz")).length, 0);
    ok(calls.at(-1)?.url.endsWith("release_ai_request"));
  }
});

Deno.test("quiz validation rejects duplicate questions and wrong explanation types", async () => {
  await rejects(() => validateQuiz({ questions: [question, question] }, 2), "ai_invalid_quiz");
  await rejects(
    () => validateQuiz({ questions: [{ ...question, explanation: 3 }] }, 1),
    "ai_invalid_quiz",
  );
});

Deno.test("timeouts are reported without persisting or leaking upstream errors", async () => {
  await rejects(() =>
    timedFetch(
      () => Promise.reject(new DOMException("do not disclose", "TimeoutError")),
      "https://example.test",
      {},
    ), "upstream_timeout");
});
