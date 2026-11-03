import { Backend, Config, Fetcher, loadConfig } from "../_shared/backend.ts";
import { Gemini } from "../_shared/gemini.ts";
import {
  handleErrors,
  HttpError,
  json,
  optionalUuid,
  readBody,
  textField,
  uuidPattern,
} from "../_shared/http.ts";

export function createHandler(config?: Config, fetcher: Fetcher = fetch) {
  return handleErrors(async (request) => {
    const backend = new Backend(config ?? loadConfig(), fetcher);
    const owner = await backend.authenticate(request);
    const body = await readBody(request);
    const title = textField(body, "title", 200);
    const topic = textField(body, "topic", 2000);
    const documentId = optionalUuid(body, "document_id");
    const count = body.question_count;
    if (!Number.isInteger(count) || Number(count) < 1 || Number(count) > 30) {
      throw new HttpError(400, "Số câu hỏi phải từ 1 đến 30.", "invalid_input");
    }
    const lease = await backend.rpc<string>("acquire_ai_request", {
      p_owner_id: owner,
      p_scope: "generate-quiz",
      p_resource_id: documentId,
    });
    try {
      const document = documentId ? await backend.documentParts(documentId, owner) : [];
      const questions = await new Gemini(backend.config, fetcher).quiz(
        topic,
        Number(count),
        document,
      );
      const result = await backend.rpc<{ quiz_id: string }>("create_generated_quiz", {
        p_owner_id: owner,
        p_title: title,
        p_topic: topic,
        p_document_id: documentId,
        p_questions: questions,
      });
      if (!result || !uuidPattern.test(result.quiz_id)) {
        throw new HttpError(503, "Không thể xác nhận bộ câu hỏi đã lưu.", "database_unavailable");
      }
      // Return only the identifier. Correct answers never leave the server before submission.
      return json({ quiz_id: result.quiz_id });
    } finally {
      try {
        await backend.rpc("release_ai_request", { p_request_id: lease });
      } catch {
        console.error("Could not release AI lease; it expires automatically.");
      }
    }
  });
}
