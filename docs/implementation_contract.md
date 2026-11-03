# Vstudy implementation contract

Backend and Flutter API reference. Original Figma exports remain unchanged in design_reference.

## Boundaries

Pure Dart domain in lib/domain/entities.dart, repositories.dart, use_cases.dart. Supabase adapters under lib/data. Flutter UI in lib/presentation; root owns composition/main.dart. Use UTC timestamps over the API and local date windows converted to UTC. SQL owner_id is always auth.uid(). Never ship a service role or Gemini API key in Flutter.

## SQL API

- profiles: id (auth user), display_name, daily_goal_minutes (default 180), timezone (default Asia/Ho_Chi_Minh), avatar_url, created_at. Signup trigger creates profile, name from auth metadata display_name.
- subjects: id, owner_id, name, color (hex string).
- study_events: id, owner_id, subject_id nullable, title, kind ('class','self_study','deadline'), starts_at, ends_at, location, notes, reminder_minutes nullable, series_id nullable. event_tasks: id, event_id, owner_id, title, is_completed.
- create_study_event(p_event jsonb, p_tasks jsonb default [], p_repeat_weeks int default 0): atomically create event and weekly occurrences (0..52 extra weeks), copy task titles. Return created event rows; client subsequently selects tasks. Update/delete operates on individual occurrence. Direct event update is allowed with ownership constraints.
- study_sessions: id, owner_id, subject_id nullable, started_at, duration_minutes (1..1440).
- documents: id, owner_id, title, storage_path, mime_type ('application/pdf','text/plain'), size_bytes, created_at. Private bucket study-documents, object path USER_UUID/DOCUMENT_UUID/filename. Max 10 MiB. Client uploads storage then inserts metadata; cleans up on failure. No automatic PDF text extraction required: AI downloads PDF server-side and submits inline Gemini data. Text documents decoded directly. Gemini client never trusts storage paths from requests; load owned document row first.
- quizzes: id, owner_id, title, topic, source_document_id nullable, created_at. quiz_questions: id, quiz_id, owner_id, position (0 based), question, options (JSON array exactly 4 strings). quiz_answer_keys: question_id, quiz_id, correct_option (0..3), explanation; service only (RLS enabled, no client policies).
- quiz_attempts: id, owner_id, quiz_id, answers (JSON object question UUID => integer 0..3), correct_count, total_questions, submitted_at. No direct insert/update grants. submit_quiz_attempt(p_quiz_id uuid, p_answers jsonb, p_attempt_id uuid): authenticated SECURITY DEFINER RPC validates owner/complete answer set, computes from private keys and persists idempotently. Returns JSON {id,quiz_id,correct_count,total_questions,submitted_at,review:[{question_id,selected_option,correct_option,explanation}]}. Same attempt UUID with different payload must reject. Attempts may repeat with new IDs. Review only after complete submit.
- chat_threads: id, owner_id, title, mode ('qa','summary','plan','flashcards'), document_id nullable, created_at, updated_at. chat_messages: id, thread_id, owner_id, role ('user','assistant'), content, created_at. Client can read/delete own threads and read messages; creation/message insertion only server service role. Atomic save_chat_turn RPC service only: p_thread_id=null creates a thread; existing ID appends to an owned thread. Parameters: p_owner_id uuid, p_thread_id uuid, p_title text, p_mode text, p_document_id uuid, p_user_content text, p_assistant_content text; returns JSON {thread_id,user_message,assistant_message} with full row objects. Shared database leases serialize concurrent turns; bounded history.
- activity home/stats are computed by Dart StudyRepository using RLS-scoped tables; no dashboard RPC required. Fetch paginated sessions/events/attempts for requested windows. Stats only uses actual sessions and submitted attempts, not planned schedule.

## Edge functions

ai-chat: POST {thread_id?:uuid, document_id?:uuid, mode:'qa'|'summary'|'plan'|'flashcards', message:string}. Existing thread's document/mode determine context; reject conflicting fields. Return {thread_id,user_message,assistant_message}. Authenticate user token explicitly. Gemini errors don't persist half a turn.

generate-quiz: POST {title:string,topic:string,document_id?:uuid,question_count:int (1..30)}. Use Gemini structured JSON, validate questions and answers, persist atomically via service-only create_generated_quiz(p_owner_id uuid,p_title text,p_topic text,p_document_id uuid,p_questions jsonb). Questions input [{question,options:[4 strings],correct_option:0..3,explanation}]. Return {quiz_id:string}. No answer keys in response/client-visible table.

Shared edge code handles auth, CORS, body size limits, input validation, owned document retrieval, bounded history, Gemini model env GEMINI_MODEL default gemini-2.5-flash, GEMINI_API_KEY, explicit fetch timeouts. Functions use Deno. Prompt treats document text as data. Do not falsely claim that citations/page references are verified.

## Dart contract

entities.dart and repositories.dart define the shared interfaces. Feature adapters use SupabaseClient injected via constructor. Domain validation/use cases throw AppException with user-safe Vietnamese message. UI invokes domain interfaces/use cases, not Supabase directly. Quiz creation uses AI from a topic or an owned document.

## Delivery

Runnable Flutter integration screens for all requested flows; original Figma files preserved as reference (not production imports). SQL migrations, RLS and ownership tests, edge unit tests, Dart unit/widget tests; docs in Vietnamese with exact setup/deploy steps and candid unverified live-service limits. No keys in git, no production deployment without a concrete user project.
