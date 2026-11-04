import { HttpError } from "./http.ts";

export const questionKinds = ["multiple_choice", "true_false", "essay"];
const stringsSchema = { type: "ARRAY", items: { type: "STRING" } };
const sectionsSchema = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    required: ["title", "points"],
    properties: { title: { type: "STRING" }, points: stringsSchema },
  },
};
export const summarySchema = {
  type: "OBJECT",
  required: ["brief", "sections", "keywords", "mind_map"],
  properties: {
    brief: stringsSchema,
    sections: sectionsSchema,
    keywords: stringsSchema,
    mind_map: sectionsSchema,
  },
};
export const worksheetSchema = {
  type: "OBJECT",
  required: ["questions"],
  properties: {
    questions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        required: [
          "kind",
          "question",
          "options",
          "correct_option",
          "explanation",
          "sample_answer",
          "hint",
        ],
        properties: {
          kind: { type: "STRING", enum: questionKinds },
          question: { type: "STRING" },
          options: stringsSchema,
          correct_option: { type: "INTEGER", minimum: -1, maximum: 3 },
          explanation: { type: "STRING" },
          sample_answer: { type: "STRING" },
          hint: { type: "STRING" },
        },
      },
    },
  },
};

const fail = (): never => {
  throw new HttpError(502, "AI chưa tạo được nội dung hợp lệ. Hãy thử lại.", "ai_invalid_material");
};
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return fail();
  return value as Record<string, unknown>;
}
function text(value: unknown, max: number, empty = false): string {
  if (typeof value !== "string" || (!empty && !value.trim()) || value.length > max) return fail();
  return value.trim();
}
function strings(value: unknown, min: number, max: number, length: number): string[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) return fail();
  return value.map((s) => text(s, length));
}
function sections(value: unknown, max: number, pointLength: number) {
  if (!Array.isArray(value) || value.length < 1 || value.length > max) return fail();
  return value.map((item) => {
    const row = object(item);
    return {
      title: text(row.title, 120),
      points: strings(row.points, 1, 8, pointLength),
    };
  });
}
export function validateSummary(value: unknown) {
  const row = object(value);
  const result = {
    brief: strings(row.brief, 1, 8, 800),
    sections: sections(row.sections, 12, 1000),
    keywords: strings(row.keywords, 1, 12, 60),
    mind_map: sections(row.mind_map, 8, 120),
  };
  if (new TextEncoder().encode(JSON.stringify(result)).length > 150000) return fail();
  return result;
}
export function validateWorksheet(value: unknown, count: number, kinds: string[]) {
  const row = object(value);
  if (!Array.isArray(row.questions) || row.questions.length !== count) return fail();
  const seen = new Set<string>();
  const usedKinds = new Set<string>();
  const questions = row.questions.map((item) => {
    const q = object(item);
    if (typeof q.kind !== "string" || !kinds.includes(q.kind)) return fail();
    const question = text(q.question, 1500);
    const normalized = question.toLocaleLowerCase("vi");
    if (seen.has(normalized)) return fail();
    seen.add(normalized);
    usedKinds.add(q.kind);
    const n = q.kind === "essay" ? 0 : q.kind === "true_false" ? 2 : 4;
    const options = strings(q.options, n, n, 500);
    if (new Set(options.map((s) => s.toLocaleLowerCase("vi"))).size !== n) return fail();
    if (
      q.kind === "true_false" &&
      options.map((s) => s.toLocaleLowerCase("vi")).join("|") !== "đúng|sai"
    ) return fail();
    if (
      !Number.isInteger(q.correct_option) ||
      (n === 0
        ? q.correct_option !== -1
        : Number(q.correct_option) < 0 || Number(q.correct_option) >= n)
    ) return fail();
    return {
      kind: q.kind,
      question,
      options,
      correct_option: q.correct_option,
      explanation: text(q.explanation, 1500),
      sample_answer: text(q.sample_answer, 2500, n !== 0),
      hint: text(q.hint, 300),
    };
  });
  if (kinds.some((kind) => !usedKinds.has(kind))) return fail();
  const result = { questions };
  if (new TextEncoder().encode(JSON.stringify(result)).length > 150000) return fail();
  return result;
}
