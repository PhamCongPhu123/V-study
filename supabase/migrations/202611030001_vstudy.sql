-- Vstudy: private per-user study data. Gemini/service keys never reach Flutter.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  daily_goal_minutes integer not null default 180 check (daily_goal_minutes between 1 and 1440),
  timezone text not null default 'Asia/Ho_Chi_Minh' check (char_length(timezone) between 1 and 100),
  avatar_url text,
  created_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), ''), 100));
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();
-- Also covers users created before this migration.
insert into public.profiles(id, display_name)
select id, left(coalesce(nullif(btrim(raw_user_meta_data ->> 'display_name'), ''),
  nullif(btrim(raw_user_meta_data ->> 'full_name'), ''),
  nullif(btrim(raw_user_meta_data ->> 'name'), ''), ''), 100) from auth.users
on conflict (id) do nothing;

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  color text not null default '#735BF2' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  unique(id, owner_id)
);
create table public.study_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  kind text not null check (kind in ('class','self_study','deadline')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  location text not null default '' check (char_length(location) <= 500),
  notes text not null default '' check (char_length(notes) <= 10000),
  reminder_minutes integer check (reminder_minutes between 0 and 10080),
  series_id uuid,
  created_at timestamptz not null default now(),
  check (ends_at >= starts_at),
  unique(id,owner_id),
  foreign key (subject_id,owner_id) references public.subjects(id,owner_id) on delete set null (subject_id)
);
create index study_events_owner_starts_idx on public.study_events(owner_id,starts_at);
create index study_events_owner_ends_idx on public.study_events(owner_id,ends_at);
create table public.event_tasks (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  owner_id uuid not null default auth.uid(),
  title text not null check (char_length(btrim(title)) between 1 and 300),
  is_completed boolean not null default false,
  foreign key (event_id,owner_id) references public.study_events(id,owner_id) on delete cascade
);
create index event_tasks_event_idx on public.event_tasks(event_id);
create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid,
  started_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes between 1 and 1440),
  created_at timestamptz not null default now(),
  foreign key (subject_id,owner_id) references public.subjects(id,owner_id) on delete set null (subject_id)
);
create index study_sessions_owner_started_idx on public.study_sessions(owner_id,started_at);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  storage_path text not null unique,
  mime_type text not null check (mime_type in ('application/pdf','text/plain')),
  size_bytes integer not null check (size_bytes between 1 and 10485760),
  created_at timestamptz not null default now(),
  unique(id,owner_id),
  check (split_part(storage_path,'/',1) = owner_id::text
         and split_part(storage_path,'/',2) = id::text
         and split_part(storage_path,'/',3) ~ '^[A-Za-z0-9._-]{1,120}$'
         and split_part(storage_path,'/',3) not in ('.','..')
         and array_length(string_to_array(storage_path,'/'),1) = 3)
);
create index documents_owner_created_idx on public.documents(owner_id,created_at desc);
create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  topic text not null default '' check (char_length(topic) <= 2000),
  source_document_id uuid,
  created_at timestamptz not null default now(),
  unique(id,owner_id),
  foreign key(source_document_id,owner_id) references public.documents(id,owner_id) on delete set null (source_document_id)
);
create index quizzes_owner_created_idx on public.quizzes(owner_id,created_at desc);
create function public.valid_quiz_options(p_options jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p_options) is distinct from 'array' then return false; end if;
  if jsonb_array_length(p_options) <> 4 then return false; end if;
  return not exists (select 1 from jsonb_array_elements(p_options) item
    where jsonb_typeof(item) <> 'string' or char_length(btrim(item #>> '{}')) not between 1 and 2000);
end;
$$;
create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null,
  owner_id uuid not null,
  position integer not null check(position between 0 and 29),
  question text not null check (char_length(btrim(question)) between 1 and 4000),
  options jsonb not null check (public.valid_quiz_options(options)),
  unique(quiz_id,position),
  unique(id,quiz_id),
  foreign key(quiz_id,owner_id) references public.quizzes(id,owner_id) on delete cascade
);
create table public.quiz_answer_keys (
  question_id uuid primary key,
  quiz_id uuid not null,
  correct_option integer not null check(correct_option between 0 and 3),
  explanation text not null default '' check(char_length(explanation) <= 8000),
  foreign key(question_id,quiz_id) references public.quiz_questions(id,quiz_id) on delete cascade
);
create index quiz_answer_keys_quiz_idx on public.quiz_answer_keys(quiz_id);
create table public.quiz_attempts (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  quiz_id uuid not null,
  answers jsonb not null check(jsonb_typeof(answers) = 'object'),
  correct_count integer not null check(correct_count >= 0),
  total_questions integer not null check(total_questions between 1 and 30),
  submitted_at timestamptz not null default now(),
  check(correct_count <= total_questions),
  foreign key(quiz_id,owner_id) references public.quizzes(id,owner_id) on delete cascade
);
create index quiz_attempts_owner_submitted_idx on public.quiz_attempts(owner_id,submitted_at desc);

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check(char_length(btrim(title)) between 1 and 200),
  mode text not null check(mode in ('qa','summary','plan','flashcards')),
  document_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id,owner_id),
  foreign key(document_id,owner_id) references public.documents(id,owner_id) on delete set null (document_id)
);
create index chat_threads_owner_updated_idx on public.chat_threads(owner_id,updated_at desc);
create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null,
  owner_id uuid not null,
  role text not null check(role in ('user','assistant')),
  content text not null check(char_length(btrim(content)) between 1 and 60000),
  created_at timestamptz not null default now(),
  foreign key(thread_id,owner_id) references public.chat_threads(id,owner_id) on delete cascade
);
create index chat_messages_thread_created_idx on public.chat_messages(thread_id,created_at,id);

-- Reset potentially broad Supabase default table privileges BEFORE adding exact grants.
-- TRUNCATE bypasses RLS, and table UPDATE would override restricted column grants.
revoke all on public.profiles,public.subjects,public.study_events,public.event_tasks,
  public.study_sessions,public.documents,public.quizzes,public.quiz_questions,
  public.quiz_answer_keys,public.quiz_attempts,public.chat_threads,public.chat_messages
  from public,anon,authenticated;
-- RLS + explicit grants: authenticated users cannot forge generated content or grades.
alter table public.profiles enable row level security;
create policy profiles_select on public.profiles for select to authenticated using(id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated using(id = (select auth.uid())) with check(id = (select auth.uid()));
grant select on public.profiles to authenticated;
grant update(display_name,daily_goal_minutes,timezone,avatar_url) on public.profiles to authenticated;

do $$ declare t text; begin
  foreach t in array array['subjects','study_events','event_tasks','study_sessions','documents'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy own_select on public.%I for select to authenticated using(owner_id = (select auth.uid()))',t);
    execute format('create policy own_insert on public.%I for insert to authenticated with check(owner_id = (select auth.uid()))',t);
    execute format('create policy own_update on public.%I for update to authenticated using(owner_id = (select auth.uid())) with check(owner_id = (select auth.uid()))',t);
    execute format('create policy own_delete on public.%I for delete to authenticated using(owner_id = (select auth.uid()))',t);
    execute format('grant select,insert,update,delete on public.%I to authenticated',t);
  end loop;
  foreach t in array array['quizzes','quiz_questions','quiz_attempts','chat_threads','chat_messages'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy own_select on public.%I for select to authenticated using(owner_id = (select auth.uid()))',t);
    execute format('grant select on public.%I to authenticated',t);
  end loop;
end; $$;
create policy own_delete on public.quizzes for delete to authenticated using(owner_id = (select auth.uid()));
create policy own_delete on public.chat_threads for delete to authenticated using(owner_id = (select auth.uid()));
grant delete on public.quizzes,public.chat_threads to authenticated;
alter table public.quiz_answer_keys enable row level security;
-- Supabase may supply broad default grants; revoke explicitly, independent of RLS.
revoke all on public.quiz_answer_keys from public,anon,authenticated;
revoke insert,update on public.quizzes,public.quiz_questions,public.quiz_attempts,public.chat_threads,public.chat_messages from public,anon,authenticated;
revoke delete on public.quiz_questions,public.quiz_attempts,public.chat_messages from public,anon,authenticated;
grant all on public.profiles,public.subjects,public.study_events,public.event_tasks,public.study_sessions,public.documents,public.quizzes,public.quiz_questions,public.quiz_answer_keys,public.quiz_attempts,public.chat_threads,public.chat_messages to service_role;

create function public.create_study_event(p_event jsonb, p_tasks jsonb default '[]', p_repeat_weeks integer default 0)
returns setof public.study_events language plpgsql security invoker set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_series uuid; v_event public.study_events; v_task jsonb; i integer;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_repeat_weeks is null or p_repeat_weeks not between 0 and 52 then raise exception 'Invalid repeat weeks' using errcode='22023'; end if;
  if jsonb_typeof(p_event) is distinct from 'object' or jsonb_typeof(p_tasks) is distinct from 'array' then raise exception 'Invalid event or tasks' using errcode='22023'; end if;
  if jsonb_array_length(p_tasks) > 50 then raise exception 'Too many tasks' using errcode='22023'; end if;
  if p_repeat_weeks > 0 then v_series := gen_random_uuid(); end if;
  for i in 0..p_repeat_weeks loop
    insert into public.study_events(owner_id,subject_id,title,kind,starts_at,ends_at,location,notes,reminder_minutes,series_id)
    values(v_owner,nullif(p_event->>'subject_id','')::uuid,p_event->>'title',p_event->>'kind',
      (p_event->>'starts_at')::timestamptz + i * interval '7 days',
      (p_event->>'ends_at')::timestamptz + i * interval '7 days',
      coalesce(p_event->>'location',''),coalesce(p_event->>'notes',''),
      (p_event->>'reminder_minutes')::integer,v_series) returning * into v_event;
    for v_task in select * from jsonb_array_elements(p_tasks) loop
      if jsonb_typeof(v_task) is distinct from 'string' then raise exception 'Tasks must be strings' using errcode='22023'; end if;
      insert into public.event_tasks(event_id,owner_id,title) values(v_event.id,v_owner,v_task #>> '{}');
    end loop;
    return next v_event;
  end loop;
end;
$$;
revoke all on function public.create_study_event(jsonb,jsonb,integer) from public,anon;
grant execute on function public.create_study_event(jsonb,jsonb,integer) to authenticated;

create function public.create_generated_quiz(p_owner_id uuid,p_title text,p_topic text,p_document_id uuid,p_questions jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_quiz uuid; v_question uuid; item jsonb; i integer := 0;
begin
  if p_owner_id is null or jsonb_typeof(p_questions) is distinct from 'array' then raise exception 'Invalid quiz'; end if;
  if jsonb_array_length(p_questions) not between 1 and 30 then raise exception 'Invalid question count'; end if;
  insert into public.quizzes(owner_id,title,topic,source_document_id) values(p_owner_id,p_title,p_topic,p_document_id) returning id into v_quiz;
  for item in select * from jsonb_array_elements(p_questions) loop
    if jsonb_typeof(item->'correct_option') is distinct from 'number' or (item->>'correct_option') !~ '^[0-3]$' then raise exception 'Invalid answer'; end if;
    insert into public.quiz_questions(quiz_id,owner_id,position,question,options)
      values(v_quiz,p_owner_id,i,item->>'question',item->'options') returning id into v_question;
    insert into public.quiz_answer_keys(question_id,quiz_id,correct_option,explanation)
      values(v_question,v_quiz,(item->>'correct_option')::integer,coalesce(item->>'explanation',''));
    i := i+1;
  end loop;
  return jsonb_build_object('quiz_id',v_quiz);
end;
$$;
revoke all on function public.create_generated_quiz(uuid,text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.create_generated_quiz(uuid,text,text,uuid,jsonb) to service_role;

create function public.submit_quiz_attempt(p_quiz_id uuid,p_answers jsonb,p_attempt_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_count integer; v_correct integer; v_attempt public.quiz_attempts; v_review jsonb;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_attempt_id is null or jsonb_typeof(p_answers) is distinct from 'object' then raise exception 'Invalid submission' using errcode='22023'; end if;
  -- Advisory lock serializes retries, including colliding IDs from different users.
  perform pg_advisory_xact_lock(hashtextextended(p_attempt_id::text,0));
  if not exists(select 1 from public.quizzes where id=p_quiz_id and owner_id=v_owner) then raise exception 'Quiz not found' using errcode='42501'; end if;
  select * into v_attempt from public.quiz_attempts where id=p_attempt_id;
  if found then
    if v_attempt.owner_id <> v_owner or v_attempt.quiz_id <> p_quiz_id or v_attempt.answers <> p_answers then
      raise exception 'Attempt identifier already used with different answers' using errcode='22023';
    end if;
  else
    select count(*) into v_count from public.quiz_questions where quiz_id=p_quiz_id;
    if v_count = 0 or (select count(*) from jsonb_object_keys(p_answers)) <> v_count then raise exception 'Answer every question exactly once' using errcode='22023'; end if;
    if exists(select 1 from public.quiz_questions q where q.quiz_id=p_quiz_id and
      (not (p_answers ? q.id::text) or jsonb_typeof(p_answers->q.id::text) is distinct from 'number' or (p_answers->>q.id::text) !~ '^[0-3]$'))
      then raise exception 'Invalid question or answer' using errcode='22023'; end if;
    if (select count(*) from public.quiz_answer_keys where quiz_id=p_quiz_id) <> v_count then raise exception 'Quiz is incomplete'; end if;
    select count(*) into v_correct from public.quiz_answer_keys k where k.quiz_id=p_quiz_id and k.correct_option=(p_answers->>k.question_id::text)::integer;
    insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions)
      values(p_attempt_id,v_owner,p_quiz_id,p_answers,v_correct,v_count) returning * into v_attempt;
  end if;
  select jsonb_agg(jsonb_build_object('question_id',q.id,'selected_option',(p_answers->>q.id::text)::integer,'correct_option',k.correct_option,'explanation',k.explanation) order by q.position)
    into v_review from public.quiz_questions q join public.quiz_answer_keys k on k.question_id=q.id where q.quiz_id=p_quiz_id;
  return (to_jsonb(v_attempt)-'owner_id'-'answers') || jsonb_build_object('review',v_review);
end;
$$;
revoke all on function public.submit_quiz_attempt(uuid,jsonb,uuid) from public,anon;
grant execute on function public.submit_quiz_attempt(uuid,jsonb,uuid) to authenticated;

create function public.save_chat_turn(p_owner_id uuid,p_thread_id uuid,p_title text,p_mode text,p_document_id uuid,p_user_content text,p_assistant_content text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_thread public.chat_threads; v_user public.chat_messages; v_assistant public.chat_messages; v_now timestamptz := clock_timestamp();
begin
  if p_owner_id is null then raise exception 'Owner required'; end if;
  if p_thread_id is null then
    insert into public.chat_threads(owner_id,title,mode,document_id) values(p_owner_id,p_title,p_mode,p_document_id) returning * into v_thread;
  else
    select * into v_thread from public.chat_threads where id=p_thread_id and owner_id=p_owner_id for update;
    if not found then raise exception 'Thread not found' using errcode='42501'; end if;
    if v_thread.mode is distinct from p_mode or v_thread.document_id is distinct from p_document_id then raise exception 'Thread context cannot change' using errcode='22023'; end if;
    update public.chat_threads set updated_at=v_now where id=p_thread_id returning * into v_thread;
  end if;
  insert into public.chat_messages(thread_id,owner_id,role,content,created_at) values(v_thread.id,p_owner_id,'user',p_user_content,v_now) returning * into v_user;
  insert into public.chat_messages(thread_id,owner_id,role,content,created_at) values(v_thread.id,p_owner_id,'assistant',p_assistant_content,v_now+interval '1 microsecond') returning * into v_assistant;
  return jsonb_build_object('thread_id',v_thread.id,'user_message',to_jsonb(v_user),'assistant_message',to_jsonb(v_assistant));
end;
$$;
revoke all on function public.save_chat_turn(uuid,uuid,text,text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.save_chat_turn(uuid,uuid,text,text,uuid,text,text) to service_role;

-- Private file objects use USER_UUID/DOCUMENT_UUID/filename. Metadata is owned too.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('study-documents','study-documents',false,10485760,array['application/pdf','text/plain'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy study_documents_select on storage.objects for select to authenticated
using(bucket_id='study-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy study_documents_insert on storage.objects for insert to authenticated
with check(bucket_id='study-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy study_documents_update on storage.objects for update to authenticated
using(bucket_id='study-documents' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='study-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy study_documents_delete on storage.objects for delete to authenticated
using(bucket_id='study-documents' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Shared rate limits and cross-isolate concurrency leases for paid AI calls.
create table public.ai_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check(scope in ('ai-chat','generate-quiz')),
  resource_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default (clock_timestamp()+interval '120 seconds'),
  released_at timestamptz
);
create index ai_requests_owner_created_idx on public.ai_requests(owner_id,created_at desc);
alter table public.ai_requests enable row level security;
revoke all on public.ai_requests from public,anon,authenticated;
grant all on public.ai_requests to service_role;
create function public.acquire_ai_request(p_owner_id uuid,p_scope text,p_resource_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_now timestamptz := clock_timestamp();
begin
  if p_owner_id is null or p_scope is null or p_scope not in ('ai-chat','generate-quiz') then raise exception 'Invalid AI request' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_owner_id::text,1));
  -- Keep this table bounded without losing the current rate-limit window.
  delete from public.ai_requests where owner_id=p_owner_id and expires_at < v_now-interval '10 minutes';
  if (select count(*) from public.ai_requests where owner_id=p_owner_id and created_at > v_now-interval '1 minute') >= 30 then
    raise exception 'AI rate limit exceeded' using errcode='P0429';
  end if;
  if exists(select 1 from public.ai_requests where owner_id=p_owner_id and scope=p_scope and resource_id is not distinct from p_resource_id and released_at is null and expires_at > v_now) then
    raise exception 'AI request already in progress' using errcode='P0409';
  end if;
  insert into public.ai_requests(owner_id,scope,resource_id,created_at,expires_at)
    values(p_owner_id,p_scope,p_resource_id,v_now,v_now+interval '120 seconds') returning id into v_id;
  return v_id;
end;
$$;
create function public.release_ai_request(p_request_id uuid)
returns void language sql security definer set search_path = '' as $$
  update public.ai_requests set released_at=clock_timestamp() where id=p_request_id and released_at is null;
$$;
revoke all on function public.acquire_ai_request(uuid,text,uuid),public.release_ai_request(uuid) from public,anon,authenticated;
grant execute on function public.acquire_ai_request(uuid,text,uuid),public.release_ai_request(uuid) to service_role;
