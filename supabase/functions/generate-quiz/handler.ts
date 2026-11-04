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
    const subjectId = optionalUuid(body, "subject_id");
    const chapterId = optionalUuid(body, "chapter_id");
    const duration = body.duration_minutes ?? 30;
    const difficulty = body.difficulty ?? "medium";
    const count = body.question_count;
    if (!Number.isInteger(count) || Number(count) < 1 || Number(count) > 30) {
      throw new HttpError(400, "Số câu hỏi phải từ 1 đến 30.", "invalid_input");
    }
    if (
      !Number.isInteger(duration) || Number(duration) < 1 || Number(duration) > 180 ||
      typeof difficulty !== "string" || !["easy", "medium", "hard"].includes(difficulty) ||
      (chapterId && !subjectId)
    ) {
      throw new HttpError(
        400,
        "Môn học, chương hoặc thời gian làm bài không hợp lệ.",
        "invalid_input",
      );
    }
    if (subjectId) {
      await backend.ownedRow("subjects", subjectId, owner, "id");
    }
    if (chapterId) {
      const chapter = await backend.ownedRow<{ subject_id: string }>(
        "quiz_chapters",
        chapterId,
        owner,
        "id,subject_id",
      );
      if (chapter.subject_id !== subjectId) {
        throw new HttpError(400, "Chương không thuộc môn học đã chọn.", "invalid_input");
      }
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
        difficulty,
      );
      const result = await backend.rpc<{ quiz_id: string }>("create_generated_quiz", {
        p_owner_id: owner,
        p_title: title,
        p_topic: topic,
        p_document_id: documentId,
        p_questions: questions,
        p_subject_id: subjectId,
        p_chapter_id: chapterId,
        p_duration_minutes: duration,
        p_difficulty: difficulty,
      });
      if (!result || !uuidPattern.test(result.quiz_id)) {
        throw new HttpError(503, "Không thể xác nhận bộ câu hỏi đã lưu.", "database_unavailable");
      }
      // Return only the identifier. Answer feedback uses separately authenticated practice/submission RPCs.
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
