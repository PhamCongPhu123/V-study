-- Additive statistics records. Run after 0002; no existing data is replaced.
begin;

create table public.study_goals (
  owner_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  weekly_minutes integer not null default 900 check(weekly_minutes between 60 and 10080),
  study_days_per_week integer not null default 5 check(study_days_per_week between 1 and 7),
  flashcards_per_day integer not null default 20 check(flashcards_per_day between 1 and 1000),
  semester_start date not null,
  semester_end date not null,
  updated_at timestamptz not null default clock_timestamp(),
  check(isfinite(semester_start) and isfinite(semester_end)),
  check(semester_end-semester_start between 7 and 366)
);

create table public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid,
  started_at timestamptz not null check(isfinite(started_at)),
  planned_minutes integer not null check(planned_minutes between 1 and 1440),
  focused_minutes integer not null check(focused_minutes between 0 and planned_minutes),
  interruptions integer not null default 0 check(interruptions between 0 and 1000),
  foreign key(subject_id,owner_id) references public.subjects(id,owner_id) on delete set null(subject_id)
);
create index focus_sessions_owner_started_idx on public.focus_sessions(owner_id,started_at,id);

create table public.flashcard_sessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid,
  reviewed_at timestamptz not null check(isfinite(reviewed_at)),
  reviewed_cards integer not null check(reviewed_cards between 1 and 10000),
  remembered_cards integer not null check(remembered_cards between 0 and reviewed_cards),
  foreign key(subject_id,owner_id) references public.subjects(id,owner_id) on delete set null(subject_id)
);
create index flashcard_sessions_owner_reviewed_idx on public.flashcard_sessions(owner_id,reviewed_at,id);

-- These checks also protect direct REST writes, independently of Flutter forms.
-- A one-minute completion tolerance accommodates small client clock differences.
create function public.validate_focus_session() returns trigger
language plpgsql set search_path='' as $$
begin
  if new.started_at>clock_timestamp()
    or new.started_at+make_interval(mins=>new.planned_minutes)>clock_timestamp()+interval '1 minute' then
    raise exception 'Focus session must already be completed' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_focus_session() from public,anon,authenticated;
create trigger validate_focus_session before insert or update on public.focus_sessions
for each row execute function public.validate_focus_session();

create function public.validate_flashcard_session() returns trigger
language plpgsql set search_path='' as $$
begin
  if new.reviewed_at>clock_timestamp() then
    raise exception 'Flashcard review cannot be in the future' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_flashcard_session() from public,anon,authenticated;
create trigger validate_flashcard_session before insert or update on public.flashcard_sessions
for each row execute function public.validate_flashcard_session();

create function public.touch_study_goals() returns trigger
language plpgsql set search_path='' as $$
begin
  new.updated_at:=clock_timestamp();
  return new;
end;
$$;
revoke all on function public.touch_study_goals() from public,anon,authenticated;
create trigger touch_study_goals before insert or update on public.study_goals
for each row execute function public.touch_study_goals();

-- Supabase default grants can include TRUNCATE, which bypasses RLS. Reset all
-- privileges before granting only owner-scoped CRUD operations to clients.
revoke all on public.study_goals,public.focus_sessions,public.flashcard_sessions from public,anon,authenticated;
grant select,insert,update,delete on public.study_goals,public.focus_sessions,public.flashcard_sessions to authenticated;
grant all on public.study_goals,public.focus_sessions,public.flashcard_sessions to service_role;
alter table public.study_goals enable row level security;
alter table public.focus_sessions enable row level security;
alter table public.flashcard_sessions enable row level security;
create policy own_goals on public.study_goals for all to authenticated
using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy own_focus_sessions on public.focus_sessions for all to authenticated
using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy own_flashcard_sessions on public.flashcard_sessions for all to authenticated
using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));

-- Aggregation needs the private grading keys; callers receive counts only.
-- The latest event wins. At an identical timestamp practice wins over an
-- attempt, then UUID provides a deterministic tie-break (same as mistake bank).
create function public.get_chapter_mastery(p_until timestamptz)
returns table(id uuid,subject_id uuid,title text,"position" integer,
  total_questions bigint,answered_questions bigint,correct_questions bigint)
language plpgsql stable security definer set search_path='' as $$
declare v_owner uuid:=auth.uid(); v_until timestamptz;
begin
  if v_owner is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_until is null or not isfinite(p_until) then
    raise exception 'A finite statistics cutoff is required' using errcode='22023'; end if;
  v_until:=least(p_until,statement_timestamp());
  return query
  with history as (
    select a.quiz_id,e.key::uuid question_id,(e.value #>> '{}')::integer selected_option,
      a.submitted_at answered_at,a.id event_id,0 source_order
    from public.quiz_attempts a cross join lateral jsonb_each(a.answers) e
    where a.owner_id=v_owner and a.submitted_at<=v_until
    union all
    select p.quiz_id,p.question_id,p.selected_option,p.answered_at,p.id,1
    from public.quiz_practice_answers p where p.owner_id=v_owner and p.answered_at<=v_until
  ), latest as (
    select distinct on(h.question_id) h.* from history h
    order by h.question_id,h.answered_at desc,h.source_order desc,h.event_id desc
  )
  select c.id,c.subject_id,c.title,c.position,count(qq.id),
    count(qq.id) filter(where h.selected_option>=0),
    count(qq.id) filter(where h.selected_option=k.correct_option)
  from public.quiz_chapters c
  left join public.quizzes q on q.chapter_id=c.id and q.owner_id=v_owner and q.subject_id=c.subject_id
  left join public.quiz_questions qq on qq.quiz_id=q.id and qq.owner_id=v_owner
  left join latest h on h.question_id=qq.id and h.quiz_id=q.id
  left join public.quiz_answer_keys k on k.question_id=qq.id and k.quiz_id=q.id
  where c.owner_id=v_owner
  group by c.id,c.subject_id,c.title,c.position
  order by c.subject_id,c.position,c.id;
end;
$$;
revoke all on function public.get_chapter_mastery(timestamptz) from public,anon,authenticated;
grant execute on function public.get_chapter_mastery(timestamptz) to authenticated;

commit;
