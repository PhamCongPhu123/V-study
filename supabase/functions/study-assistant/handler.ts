import { Backend, Config, Fetcher, loadConfig, OwnedDocument } from "../_shared/backend.ts";
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
import { questionKinds } from "../_shared/study_content.ts";

export function createHandler(config?: Config, fetcher: Fetcher = fetch) {
  return handleErrors(async (request) => {
    const backend = new Backend(config ?? loadConfig(), fetcher);
    const owner = await backend.authenticate(request);
    const body = await readBody(request);
    const id = optionalUuid(body, "request_id");
    const kind = body.kind;
    const title = textField(body, "title", 200);
    if (!id || (kind !== "summary" && kind !== "worksheet" && kind !== "quiz")) {
      throw new HttpError(400, "Yêu cầu AI chưa hợp lệ.", "invalid_input");
    }
    const ids = body.document_ids ?? [];
    if (
      !Array.isArray(ids) || ids.length > 3 || new Set(ids).size !== ids.length ||
      !ids.every((value) => typeof value === "string" && uuidPattern.test(value)) ||
      (kind === "summary" && ids.length === 0)
    ) {
      throw new HttpError(
        400,
        "Chọn tối đa 3 tài liệu khác nhau; tóm tắt cần có tài liệu.",
        "invalid_input",
      );
    }
    const count = kind === "summary" ? 0 : body.question_count;
    const difficulty = kind === "summary" ? "medium" : body.difficulty ?? "medium";
    const kinds = kind === "summary" ? [] : body.question_kinds ?? ["multiple_choice"];
    const topic = kind === "summary" ? "" : textField(body, "topic", 2000);
    if (
      typeof difficulty !== "string" || !["easy", "medium", "hard"].includes(difficulty) ||
      !Array.isArray(kinds) || kinds.some((k) => !questionKinds.includes(k)) ||
      new Set(kinds).size !== kinds.length ||
      (kind !== "summary" &&
        (!Number.isInteger(count) || Number(count) < 1 || Number(count) > 40 ||
          kinds.length === 0 || Number(count) < kinds.length)) ||
      (kind === "quiz" && (kinds.length !== 1 || kinds[0] !== "multiple_choice"))
    ) {
      throw new HttpError(400, "Số câu, độ khó hoặc dạng câu hỏi chưa hợp lệ.", "invalid_input");
    }
    const fingerprint = Array.from(
      new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(
            JSON.stringify([kind, title, topic, ids, count, difficulty, kinds]),
          ),
        ),
      ),
    )
      .map((b) => b.toString(16).padStart(2, "0")).join("");
    const cached = async () => {
      try {
        const result = await backend.ownedRow<Record<string, unknown>>(
          "ai_artifacts",
          id,
          owner,
          "*",
        );
        if (result.request_fingerprint !== fingerprint) {
          throw new HttpError(
            409,
            "Mã yêu cầu đã được dùng cho nội dung khác.",
            "request_context_conflict",
          );
        }
        return result;
      } catch (error) {
        if (error instanceof HttpError && error.status === 404) return null;
        throw error;
      }
    };
    const existing = await cached();
    if (existing) return json(existing);
    const lease = await backend.rpc<string>("acquire_ai_request", {
      p_owner_id: owner,
      p_scope: kind === "summary" ? "ai-chat" : "generate-quiz",
      p_resource_id: id,
    });
    try {
      const ready = await cached();
      if (ready) return json(ready);
      const docs = await Promise.all(ids.map((documentId) =>
        backend.ownedRow<OwnedDocument>(
          "documents",
          documentId,
          owner,
          "id,owner_id,title,storage_path,mime_type,size_bytes",
        )
      ));
      if (
        docs.some((doc) => !Number.isSafeInteger(doc.size_bytes) || doc.size_bytes <= 0) ||
        docs.reduce((sum, d) => sum + d.size_bytes, 0) > 10 * 1024 * 1024
      ) {
        throw new HttpError(
          400,
          "Tổng tài liệu cho một yêu cầu tối đa 10 MiB.",
          "invalid_document",
        );
      }
      const parts = (await Promise.all(docs.map((doc, i) =>
        backend.documentParts(ids[i], owner, doc)
      ))).flat();
      const gemini = new Gemini(backend.config, fetcher);
      const questions = kind === "quiz"
        ? await gemini.quiz(topic, Number(count), parts, difficulty)
        : null;
      const content = kind === "quiz"
        ? {}
        : await gemini.material(kind, topic, Number(count), difficulty, kinds, parts);
      const result = await backend.rpc<Record<string, unknown>>("save_ai_artifact", {
        p_id: id,
        p_owner_id: owner,
        p_kind: kind,
        p_title: title,
        p_document_ids: ids,
        p_content: content,
        p_fingerprint: fingerprint,
        p_topic: topic,
        p_questions: questions,
        p_difficulty: difficulty,
      });
      if (result.id !== id || (kind === "quiz" && !uuidPattern.test(String(result.quiz_id)))) {
        throw new HttpError(
          503,
          "Chưa xác nhận được nội dung đã lưu. Thử lại cùng yêu cầu để kiểm tra.",
          "database_unavailable",
        );
      }
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
