import { Backend, Config, Fetcher, loadConfig, Thread } from "../_shared/backend.ts";
import { Gemini } from "../_shared/gemini.ts";
import {
  handleErrors,
  HttpError,
  json,
  optionalUuid,
  readBody,
  textField,
} from "../_shared/http.ts";

export function createHandler(config?: Config, fetcher: Fetcher = fetch) {
  return handleErrors(async (request) => {
    const backend = new Backend(config ?? loadConfig(), fetcher);
    const owner = await backend.authenticate(request);
    const body = await readBody(request);
    const message = textField(body, "message", 8000);
    const existingThreadId = optionalUuid(body, "thread_id");
    let documentId = optionalUuid(body, "document_id");
    const requestedMode = body.mode ?? "qa";
    if (
      typeof requestedMode !== "string" ||
      !["qa", "summary", "plan", "flashcards"].includes(requestedMode)
    ) {
      throw new HttpError(400, "Chế độ AI không hợp lệ.", "invalid_input");
    }
    let mode: string = requestedMode;
    if (existingThreadId) {
      const thread = await backend.ownedRow<Thread>(
        "chat_threads",
        existingThreadId,
        owner,
        "id,owner_id,title,mode,document_id",
      );
      if (
        (body.mode !== undefined && mode !== thread.mode) ||
        (body.document_id !== undefined && documentId !== thread.document_id)
      ) {
        throw new HttpError(
          409,
          "Hãy tạo hội thoại mới khi đổi tài liệu hoặc chế độ.",
          "thread_context_conflict",
        );
      }
      documentId = thread.document_id;
      mode = thread.mode;
    }
    const lease = await backend.rpc<string>("acquire_ai_request", {
      p_owner_id: owner,
      p_scope: "ai-chat",
      p_resource_id: existingThreadId,
    });
    try {
      const document = documentId ? await backend.documentParts(documentId, owner) : [];
      const history = existingThreadId ? await backend.history(existingThreadId, owner) : [];
      const answer = await new Gemini(backend.config, fetcher).chat(
        mode,
        message,
        history,
        document,
      );
      const result = await backend.rpc<Record<string, unknown>>("save_chat_turn", {
        p_owner_id: owner,
        p_thread_id: existingThreadId,
        p_title: message.slice(0, 100),
        p_mode: mode,
        p_document_id: documentId,
        p_user_content: message,
        p_assistant_content: answer,
      });
      return json(result);
    } finally {
      try {
        await backend.rpc("release_ai_request", { p_request_id: lease });
      } catch {
        console.error("Could not release AI lease; it expires automatically.");
      }
    }
  });
}
