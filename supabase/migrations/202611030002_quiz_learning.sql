-- Additive learning catalog and explicit practice feedback. Run after 0001.
begin;
create table public.quiz_chapters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid not null,
  title text not null check(char_length(btrim(title)) between 1 and 200),
  position integer not null default 0 check(position between 0 and 1000),
  created_at timestamptz not null default clock_timestamp(),
  unique(id,owner_id,subject_id),
  unique(subject_id,position),
  foreign key(subject_id,owner_id) references public.subjects(id,owner_id) on delete cascade
);
alter table public.quiz_chapters enable row level security;
revoke all on public.quiz_chapters from public,anon,authenticated;
grant select,insert,update,delete on public.quiz_chapters to authenticated;
grant all on public.quiz_chapters to service_role;
create policy own_chapters on public.quiz_chapters for all to authenticated
using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));

alter table public.quizzes
  add column subject_id uuid,
  add column chapter_id uuid,
  add column duration_minutes integer not null default 30 check(duration_minutes between 1 and 180),
  add column difficulty text not null default 'medium' check(difficulty in ('easy','medium','hard')),
  add constraint quizzes_subject_owner_fk foreign key(subject_id,owner_id) references public.subjects(id,owner_id),
  add constraint quizzes_chapter_owner_fk foreign key(chapter_id,owner_id,subject_id) references public.quiz_chapters(id,owner_id,subject_id),
  add constraint quizzes_chapter_needs_subject check(chapter_id is null or subject_id is not null);
create index quizzes_subject_idx on public.quizzes(owner_id,subject_id,chapter_id);

alter table public.quiz_attempts add column mode text not null default 'practice' check(mode in ('practice','exam'));

create table public.quiz_practice_answers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  quiz_id uuid not null,
  question_id uuid not null,
  selected_option integer not null check(selected_option between 0 and 3),
  answered_at timestamptz not null default clock_timestamp(),
  foreign key(quiz_id,owner_id) references public.quizzes(id,owner_id) on delete cascade,
  foreign key(question_id,quiz_id) references public.quiz_questions(id,quiz_id) on delete cascade
);
create index quiz_practice_owner_question_idx on public.quiz_practice_answers(owner_id,question_id,answered_at desc);
alter table public.quiz_practice_answers enable row level security;
revoke all on public.quiz_practice_answers from public,anon,authenticated;
grant all on public.quiz_practice_answers to service_role;

create function public.list_quiz_chapters(p_subject_id uuid)
returns table(id uuid,subject_id uuid,title text,"position" integer,question_count bigint)
language sql stable security definer set search_path='' as $$
  select c.id,c.subject_id,c.title,c.position,count(qq.id)
  from public.quiz_chapters c
  left join public.quizzes q on q.chapter_id=c.id and q.owner_id=auth.uid()
  left join public.quiz_questions qq on qq.quiz_id=q.id
  where c.owner_id=auth.uid() and c.subject_id=p_subject_id
  group by c.id,c.subject_id,c.title,c.position order by c.position,c.id;
$$;
revoke all on function public.list_quiz_chapters(uuid) from public,anon;
grant execute on function public.list_quiz_chapters(uuid) to authenticated;

create function public.create_quiz_chapter(p_subject_id uuid,p_title text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.quiz_chapters; v_owner uuid:=auth.uid(); v_position integer;
begin
  if v_owner is null or not exists(select 1 from public.subjects where id=p_subject_id and owner_id=v_owner) then
    raise exception 'Subject not found' using errcode='42501'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 200 then
    raise exception 'Invalid chapter title' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_subject_id::text,2));
  select coalesce(max(position),-1)+1 into v_position from public.quiz_chapters where subject_id=p_subject_id;
  insert into public.quiz_chapters(owner_id,subject_id,title,position)
    values(v_owner,p_subject_id,btrim(p_title),v_position) returning * into c;
  return jsonb_build_object('id',c.id,'subject_id',c.subject_id,'title',c.title,
    'position',c.position,'question_count',0);
end;
$$;
revoke all on function public.create_quiz_chapter(uuid,text) from public,anon;
grant execute on function public.create_quiz_chapter(uuid,text) to authenticated;

create function public.get_quiz_attempt(p_attempt_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.quiz_attempts; review jsonb;
begin
  select * into a from public.quiz_attempts where id=p_attempt_id and owner_id=auth.uid();
  if not found then raise exception 'Attempt not found' using errcode='42501'; end if;
  select jsonb_agg(jsonb_build_object('question_id',q.id,
    'selected_option',coalesce((a.answers->>q.id::text)::integer,-1),
    'correct_option',k.correct_option,'explanation',k.explanation) order by q.position)
  into review from public.quiz_questions q join public.quiz_answer_keys k on k.question_id=q.id
  where q.quiz_id=a.quiz_id;
  return (to_jsonb(a)-'owner_id'-'answers') || jsonb_build_object('review',review);
end;
$$;
revoke all on function public.get_quiz_attempt(uuid) from public,anon;
grant execute on function public.get_quiz_attempt(uuid) to authenticated;

drop function public.submit_quiz_attempt(uuid,jsonb,uuid);
create function public.submit_quiz_attempt(p_quiz_id uuid,p_answers jsonb,p_attempt_id uuid,p_allow_unanswered boolean default false,p_mode text default 'practice')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_count integer; v_correct integer; v_answers jsonb; a public.quiz_attempts;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_attempt_id is null or p_allow_unanswered is null or p_mode is null or p_mode not in ('practice','exam') or jsonb_typeof(p_answers) is distinct from 'object' then
    raise exception 'Invalid submission' using errcode='22023'; end if;
  if not exists(select 1 from public.quizzes where id=p_quiz_id and owner_id=v_owner) then
    raise exception 'Quiz not found' using errcode='42501'; end if;
  -- Validate every provided entry, including extras. Missing answers are only
  -- admitted by the explicit timed-exam path and count as incorrect.
  if exists(select 1 from jsonb_each(p_answers) e where
      not exists(select 1 from public.quiz_questions q where q.quiz_id=p_quiz_id and q.id::text=e.key)
      or jsonb_typeof(e.value) is distinct from 'number' or e.value::text !~ '^[0-3]$') then
    raise exception 'Invalid question or answer' using errcode='22023'; end if;
  select count(*) into v_count from public.quiz_questions where quiz_id=p_quiz_id;
  if v_count=0 or (not p_allow_unanswered and (select count(*) from jsonb_object_keys(p_answers))<>v_count) then
    raise exception 'Answer every question exactly once' using errcode='22023'; end if;
  select jsonb_object_agg(q.id::text,coalesce(p_answers->q.id::text,'-1'::jsonb)) into v_answers
    from public.quiz_questions q where q.quiz_id=p_quiz_id;
  perform pg_advisory_xact_lock(hashtextextended(p_attempt_id::text,0));
  select * into a from public.quiz_attempts where id=p_attempt_id;
  if found then
    if a.owner_id<>v_owner or a.quiz_id<>p_quiz_id or a.answers<>v_answers or a.mode<>p_mode then
      raise exception 'Attempt identifier already used with different answers' using errcode='22023'; end if;
  else
    if (select count(*) from public.quiz_answer_keys where quiz_id=p_quiz_id)<>v_count then raise exception 'Quiz is incomplete'; end if;
    select count(*) into v_correct from public.quiz_answer_keys k
      where k.quiz_id=p_quiz_id and k.correct_option=(v_answers->>k.question_id::text)::integer;
    insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions,submitted_at,mode)
      values(p_attempt_id,v_owner,p_quiz_id,v_answers,v_correct,v_count,clock_timestamp(),p_mode);
  end if;
  return public.get_quiz_attempt(p_attempt_id);
end;
$$;
revoke all on function public.submit_quiz_attempt(uuid,jsonb,uuid,boolean,text) from public,anon;
grant execute on function public.submit_quiz_attempt(uuid,jsonb,uuid,boolean,text) to authenticated;

create function public.check_practice_answer(p_quiz_id uuid,p_question_id uuid,p_selected_option integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); k public.quiz_answer_keys;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_selected_option is null or p_selected_option not between 0 and 3 then
    raise exception 'Invalid option' using errcode='22023'; end if;
  if not exists(select 1 from public.quizzes where id=p_quiz_id and owner_id=v_owner) then
    raise exception 'Quiz not found' using errcode='42501'; end if;
  select * into k from public.quiz_answer_keys where quiz_id=p_quiz_id and question_id=p_question_id;
  if not found then raise exception 'Question not found' using errcode='42501'; end if;
  insert into public.quiz_practice_answers(owner_id,quiz_id,question_id,selected_option)
    values(v_owner,p_quiz_id,p_question_id,p_selected_option);
  return jsonb_build_object('question_id',p_question_id,'selected_option',p_selected_option,
    'correct_option',k.correct_option,'explanation',k.explanation);
end;
$$;
revoke all on function public.check_practice_answer(uuid,uuid,integer) from public,anon;
grant execute on function public.check_practice_answer(uuid,uuid,integer) to authenticated;

create function public.list_wrong_quiz_answers(p_subject_id uuid default null)
returns setof jsonb language sql stable security definer set search_path='' as $$
  with history as (
    select a.quiz_id,e.key::uuid question_id,(e.value #>> '{}')::integer selected_option,
      a.submitted_at answered_at,a.id event_id,0 source_order
    from public.quiz_attempts a cross join lateral jsonb_each(a.answers) e where a.owner_id=auth.uid()
    union all
    select p.quiz_id,p.question_id,p.selected_option,p.answered_at,p.id,1
    from public.quiz_practice_answers p where p.owner_id=auth.uid()
  ), latest as (
    select distinct on(question_id) * from history
    order by question_id,answered_at desc,source_order desc,event_id desc
  )
  select jsonb_build_object('quiz_id',q.id,'quiz_title',q.title,'subject_id',q.subject_id,
    'chapter_id',q.chapter_id,'question',jsonb_build_object('id',qq.id,'position',qq.position,
      'question',qq.question,'options',qq.options),
    'selected_option',h.selected_option,'correct_option',k.correct_option,
    'explanation',k.explanation,'answered_at',h.answered_at)
  from latest h join public.quizzes q on q.id=h.quiz_id and q.owner_id=auth.uid()
  join public.quiz_questions qq on qq.id=h.question_id and qq.quiz_id=q.id
  join public.quiz_answer_keys k on k.question_id=qq.id
  where h.selected_option<>k.correct_option and (p_subject_id is null or q.subject_id=p_subject_id)
  order by h.answered_at desc,qq.id;
$$;
revoke all on function public.list_wrong_quiz_answers(uuid) from public,anon;
grant execute on function public.list_wrong_quiz_answers(uuid) to authenticated;

drop function public.create_generated_quiz(uuid,text,text,uuid,jsonb);
create function public.create_generated_quiz(p_owner_id uuid,p_title text,p_topic text,p_document_id uuid,p_questions jsonb,
  p_subject_id uuid default null,p_chapter_id uuid default null,p_duration_minutes integer default 30,p_difficulty text default 'medium')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_quiz uuid; v_question uuid; item jsonb; i integer:=0;
begin
  if p_owner_id is null or jsonb_typeof(p_questions) is distinct from 'array' then raise exception 'Invalid quiz'; end if;
  if jsonb_array_length(p_questions) not between 1 and 30 then raise exception 'Invalid question count'; end if;
  insert into public.quizzes(owner_id,title,topic,source_document_id,subject_id,chapter_id,duration_minutes,difficulty)
    values(p_owner_id,p_title,p_topic,p_document_id,p_subject_id,p_chapter_id,p_duration_minutes,p_difficulty)
    returning id into v_quiz;
  for item in select * from jsonb_array_elements(p_questions) loop
    if jsonb_typeof(item->'correct_option') is distinct from 'number' or (item->>'correct_option') !~ '^[0-3]$' then raise exception 'Invalid answer'; end if;
    insert into public.quiz_questions(quiz_id,owner_id,position,question,options)
      values(v_quiz,p_owner_id,i,item->>'question',item->'options') returning id into v_question;
    insert into public.quiz_answer_keys(question_id,quiz_id,correct_option,explanation)
      values(v_question,v_quiz,(item->>'correct_option')::integer,coalesce(item->>'explanation',''));
    i:=i+1;
  end loop;
  return jsonb_build_object('quiz_id',v_quiz);
end;
$$;
revoke all on function public.create_generated_quiz(uuid,text,text,uuid,jsonb,uuid,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.create_generated_quiz(uuid,text,text,uuid,jsonb,uuid,uuid,integer,text) to service_role;
commit;
