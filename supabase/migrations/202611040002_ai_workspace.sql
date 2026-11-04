begin;
alter table public.quiz_questions add column hint text not null default '' check(char_length(hint) <= 300);
-- AI-created worksheets are for self study. Only official quizzes use private
-- answer keys, server grading and quiz statistics.
create table public.ai_artifacts (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check(kind in ('summary','worksheet','quiz')),
  title text not null check(char_length(btrim(title)) between 1 and 200),
  document_ids uuid[] not null default '{}' check(cardinality(document_ids) <= 3 and array_position(document_ids,null) is null),
  source_titles text[] not null default '{}' check(cardinality(source_titles) <= 3),
  content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text) <= 160000),
  quiz_id uuid,
  request_fingerprint text not null check(request_fingerprint ~ '^[a-f0-9]{64}$'),
  feedback smallint check(feedback in (-1,1)),
  created_at timestamptz not null default now(),
  check(cardinality(document_ids)=cardinality(source_titles)),
  check(kind <> 'summary' or cardinality(document_ids) >= 1),
  check((kind='quiz') = (quiz_id is not null)),
  foreign key(quiz_id,owner_id) references public.quizzes(id,owner_id) on delete cascade
);
create index ai_artifacts_owner_created_idx on public.ai_artifacts(owner_id,created_at desc,id);
alter table public.ai_artifacts enable row level security;
revoke all on public.ai_artifacts from public,anon,authenticated;
grant select,delete on public.ai_artifacts to authenticated;
grant update(feedback) on public.ai_artifacts to authenticated;
grant all on public.ai_artifacts to service_role;
create policy ai_artifacts_select on public.ai_artifacts for select to authenticated using(owner_id=(select auth.uid()));
create policy ai_artifacts_feedback on public.ai_artifacts for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy ai_artifacts_delete on public.ai_artifacts for delete to authenticated using(owner_id=(select auth.uid()));

alter table public.quiz_attempts drop constraint quiz_attempts_total_questions_check;
alter table public.quiz_attempts add constraint quiz_attempts_total_questions_check check(total_questions between 1 and 40);
alter table public.quiz_questions drop constraint quiz_questions_position_check;
alter table public.quiz_questions add constraint quiz_questions_position_check check(position between 0 and 39);
create or replace function public.create_generated_quiz(p_owner_id uuid,p_title text,p_topic text,p_document_id uuid,p_questions jsonb,
  p_subject_id uuid default null,p_chapter_id uuid default null,p_duration_minutes integer default 30,p_difficulty text default 'medium')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_quiz uuid; v_question uuid; item jsonb; i integer:=0;
begin
  if p_owner_id is null or jsonb_typeof(p_questions) is distinct from 'array' then raise exception 'Invalid quiz'; end if;
  if jsonb_array_length(p_questions) not between 1 and 40 then raise exception 'Invalid question count'; end if;
  insert into public.quizzes(owner_id,title,topic,source_document_id,subject_id,chapter_id,duration_minutes,difficulty)
    values(p_owner_id,p_title,p_topic,p_document_id,p_subject_id,p_chapter_id,p_duration_minutes,p_difficulty) returning id into v_quiz;
  for item in select * from jsonb_array_elements(p_questions) loop
    if jsonb_typeof(item->'correct_option') is distinct from 'number' or (item->>'correct_option') !~ '^[0-3]$' then raise exception 'Invalid answer'; end if;
    insert into public.quiz_questions(quiz_id,owner_id,position,question,options,hint)
      values(v_quiz,p_owner_id,i,item->>'question',item->'options',coalesce(item->>'hint','')) returning id into v_question;
    insert into public.quiz_answer_keys(question_id,quiz_id,correct_option,explanation)
      values(v_question,v_quiz,(item->>'correct_option')::integer,coalesce(item->>'explanation',''));
    i:=i+1;
  end loop;
  return jsonb_build_object('quiz_id',v_quiz);
end;
$$;
revoke all on function public.create_generated_quiz(uuid,text,text,uuid,jsonb,uuid,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.create_generated_quiz(uuid,text,text,uuid,jsonb,uuid,uuid,integer,text) to service_role;

create function public.save_ai_artifact(p_id uuid,p_owner_id uuid,p_kind text,p_title text,p_document_ids uuid[],
  p_content jsonb,p_fingerprint text,p_topic text default '',p_questions jsonb default null,p_difficulty text default 'medium')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_row public.ai_artifacts; v_quiz uuid; v_titles text[]; v_source uuid;
begin
  if p_id is null or p_owner_id is null or p_kind is null or p_kind not in ('summary','worksheet','quiz')
    or p_document_ids is null or cardinality(p_document_ids) > 3 or array_position(p_document_ids,null) is not null
    or p_fingerprint is null or p_fingerprint !~ '^[a-f0-9]{64}$' then raise exception 'Invalid artifact' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,7));
  select * into v_row from public.ai_artifacts where id=p_id;
  if found then
    if v_row.owner_id <> p_owner_id or v_row.request_fingerprint <> p_fingerprint then
      raise exception 'Request context changed' using errcode='P0409';
    end if;
    return to_jsonb(v_row);
  end if;
  if (select count(distinct x) from unnest(p_document_ids) x) <> cardinality(p_document_ids)
    or (select count(*) from public.documents where owner_id=p_owner_id and id=any(p_document_ids)) <> cardinality(p_document_ids)
    or coalesce((select sum(size_bytes) from public.documents where owner_id=p_owner_id and id=any(p_document_ids)),0) > 10485760 then
    raise exception 'Invalid source documents' using errcode='22023';
  end if;
  select coalesce(array_agg(d.title order by x.position),'{}') into v_titles
    from unnest(p_document_ids) with ordinality x(id,position) join public.documents d on d.id=x.id and d.owner_id=p_owner_id;
  if p_kind='quiz' then
    v_source := p_document_ids[1];
    v_quiz := (public.create_generated_quiz(p_owner_id,p_title,p_topic,v_source,p_questions,null,null,30,p_difficulty)->>'quiz_id')::uuid;
    -- Grading keys are never copied into the public artifact payload.
    p_content := '{}'::jsonb;
  elsif p_kind='summary' then
    if jsonb_typeof(p_content->'brief') is distinct from 'array' or jsonb_array_length(p_content->'brief') < 1
      or jsonb_typeof(p_content->'sections') is distinct from 'array'
      or jsonb_typeof(p_content->'keywords') is distinct from 'array'
      or jsonb_typeof(p_content->'mind_map') is distinct from 'array' then raise exception 'Invalid summary' using errcode='22023'; end if;
  else
    if jsonb_typeof(p_content->'questions') is distinct from 'array' or jsonb_array_length(p_content->'questions') not between 1 and 40 then
      raise exception 'Invalid worksheet' using errcode='22023'; end if;
  end if;
  insert into public.ai_artifacts(id,owner_id,kind,title,document_ids,source_titles,content,quiz_id,request_fingerprint)
    values(p_id,p_owner_id,p_kind,p_title,p_document_ids,v_titles,p_content,v_quiz,p_fingerprint) returning * into v_row;
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.save_ai_artifact(uuid,uuid,text,text,uuid[],jsonb,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.save_ai_artifact(uuid,uuid,text,text,uuid[],jsonb,text,text,jsonb,text) to service_role;
commit;
