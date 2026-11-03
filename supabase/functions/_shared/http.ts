export class HttpError extends Error {
  constructor(public status: number, message: string, public code = "request_failed") {
    super(message);
  }
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

export function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...cors, "Content-Type": "application/json; charset=utf-8" },
  });
}

export async function readBody(
  request: Request,
  maxBytes = 16384,
): Promise<Record<string, unknown>> {
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    throw new HttpError(415, "Yêu cầu phải có định dạng JSON.", "invalid_content_type");
  }
  const size = Number(request.headers.get("content-length"));
  if (Number.isFinite(size) && size > maxBytes) {
    throw new HttpError(413, "Nội dung yêu cầu quá dài.", "request_too_large");
  }
  if (!request.body) throw new HttpError(400, "Thiếu nội dung yêu cầu.", "invalid_body");
  const reader = request.body.getReader();
  const parts: Uint8Array[] = [];
  let count = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      count += value.byteLength;
      if (count > maxBytes) {
        await reader.cancel();
        throw new HttpError(413, "Nội dung yêu cầu quá dài.", "request_too_large");
      }
      parts.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(count);
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.byteLength;
  }
  try {
    const data = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error();
    return data;
  } catch {
    throw new HttpError(400, "JSON không hợp lệ.", "invalid_body");
  }
}

export function textField(body: Record<string, unknown>, key: string, max: number): string {
  const value = body[key];
  if (typeof value !== "string" || !value.trim() || value.trim().length > max) {
    throw new HttpError(400, `${key} phải có từ 1 đến ${max} ký tự.`, "invalid_input");
  }
  return value.trim();
}

export const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function optionalUuid(body: Record<string, unknown>, key: string): string | null {
  const value = body[key];
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new HttpError(400, `${key} không hợp lệ.`, "invalid_input");
  }
  return value.toLowerCase();
}

export function handleErrors(handler: (r: Request) => Promise<Response>) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") {
      return json({ error: "Chỉ hỗ trợ POST.", code: "method_not_allowed" }, 405);
    }
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message, code: error.code }, error.status);
      }
      // Never echo upstream payloads, credentials or prompts into logs or client errors.
      console.error("Vstudy function failed", error instanceof Error ? error.name : "UnknownError");
      return json({ error: "Dịch vụ tạm thời không khả dụng.", code: "internal_error" }, 500);
    }
  };
}
