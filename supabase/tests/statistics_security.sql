-- Disposable fixtures only. This file is rolled back, never run on production.
begin;
create function public.vstudy_test_assert(p_condition boolean,p_message text) returns void
language plpgsql as $$ begin if p_condition is not true then raise exception 'FAIL: %',p_message; end if; raise notice 'PASS: %',p_message; end; $$;
create function public.vstudy_test_error(p_sql text,p_state text,p_message text) returns void
language plpgsql as $$ begin begin execute p_sql; exception when others then
 if sqlstate=p_state then raise notice 'PASS: %',p_message; return; end if;
 raise exception 'FAIL: % (expected %, got %: %)',p_message,p_state,sqlstate,sqlerrm;
 end; raise exception 'FAIL: % (unexpected success)',p_message; end; $$;
grant execute on function public.vstudy_test_assert(boolean,text),public.vstudy_test_error(text,text,text) to authenticated,anon,service_role;
insert into auth.users(id,raw_user_meta_data) values
 ('11111111-1111-4111-8111-111111111111','{}'),('22222222-2222-4222-8222-222222222222','{}');
insert into public.subjects(id,owner_id,name) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Triết học'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','11111111-1111-4111-8111-111111111111','Pháp luật'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','22222222-2222-4222-8222-222222222222','Riêng tư');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.study_goals(semester_start,semester_end,updated_at) values('2026-08-01','2027-02-01','2000-01-01');
select public.vstudy_test_assert((select weekly_minutes=900 and study_days_per_week=5 and flashcards_per_day=20 from public.study_goals),'goal defaults match learning settings');
select public.vstudy_test_assert((select updated_at>'2000-01-01' from public.study_goals),'goal updated_at is stamped by server');
insert into public.study_goals(owner_id,weekly_minutes,study_days_per_week,flashcards_per_day,semester_start,semester_end)
 values('11111111-1111-4111-8111-111111111111',1200,6,30,'2026-08-01','2027-02-01')
 on conflict(owner_id) do update set weekly_minutes=excluded.weekly_minutes,study_days_per_week=excluded.study_days_per_week,flashcards_per_day=excluded.flashcards_per_day;
select public.vstudy_test_assert((select count(*)=1 and min(weekly_minutes)=1200 from public.study_goals),'owner can upsert learning goals');
select public.vstudy_test_error('update public.study_goals set weekly_minutes=59','23514','weekly goal lower bound enforced');
select public.vstudy_test_error('update public.study_goals set weekly_minutes=10081','23514','weekly goal upper bound enforced');
select public.vstudy_test_error('update public.study_goals set study_days_per_week=0','23514','study days lower bound enforced');
select public.vstudy_test_error('update public.study_goals set study_days_per_week=8','23514','study days upper bound enforced');
select public.vstudy_test_error('update public.study_goals set flashcards_per_day=0','23514','flashcard goal lower bound enforced');
select public.vstudy_test_error('update public.study_goals set flashcards_per_day=1001','23514','flashcard goal upper bound enforced');
select public.vstudy_test_error($q$update public.study_goals set semester_end=semester_start+6$q$,'23514','semester must span at least seven days');
select public.vstudy_test_error($q$update public.study_goals set semester_end=semester_start+367$q$,'23514','semester cannot exceed 366 days');
select public.vstudy_test_error($q$update public.study_goals set semester_end=semester_start-1$q$,'23514','semester end must follow start');
select public.vstudy_test_error($q$update public.study_goals set semester_start='infinity',semester_end='infinity'$q$,'23514','semester rejects infinite dates');
select public.vstudy_test_error($q$insert into public.study_goals(owner_id,semester_start,semester_end) values('22222222-2222-4222-8222-222222222222','2026-08-01','2027-02-01')$q$,'42501','cannot create another owner goals');
select public.vstudy_test_error($q$update public.study_goals set owner_id='22222222-2222-4222-8222-222222222222'$q$,'42501','cannot transfer goal ownership');

insert into public.focus_sessions(id,subject_id,started_at,planned_minutes,focused_minutes,interruptions)
 values('f1111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',clock_timestamp()-interval '1 hour',30,25,2);
insert into public.flashcard_sessions(id,subject_id,reviewed_at,reviewed_cards,remembered_cards)
 values('f2222222-2222-4222-8222-222222222222','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',clock_timestamp()-interval '1 hour',20,17);
select public.vstudy_test_assert((select focused_minutes=25 and interruptions=2 from public.focus_sessions),'direct focus insert preserves measured values');
select public.vstudy_test_assert((select reviewed_cards=20 and remembered_cards=17 from public.flashcard_sessions),'direct flashcard insert preserves review counts');
select public.vstudy_test_assert((select count(*)=0 from public.study_sessions),'focus logging does not duplicate study time');
select public.vstudy_test_error($q$insert into public.focus_sessions(started_at,planned_minutes,focused_minutes) values(clock_timestamp(),30,20)$q$,'23514','incomplete focus insert rejected independently of client');
select public.vstudy_test_error($q$insert into public.focus_sessions(started_at,planned_minutes,focused_minutes) values(clock_timestamp()+interval '1 hour',30,20)$q$,'23514','future focus start rejected');
select public.vstudy_test_error($q$update public.focus_sessions set started_at=clock_timestamp(),planned_minutes=30$q$,'23514','focus update cannot make session incomplete');
select public.vstudy_test_error($q$insert into public.focus_sessions(started_at,planned_minutes,focused_minutes) values(clock_timestamp()-interval '1 hour',0,0)$q$,'23514','focus planned minutes lower bound enforced');
select public.vstudy_test_error($q$insert into public.focus_sessions(started_at,planned_minutes,focused_minutes) values(clock_timestamp()-interval '2 days',1441,1)$q$,'23514','focus planned minutes upper bound enforced');
select public.vstudy_test_error('update public.focus_sessions set focused_minutes=-1','23514','focused minutes cannot be negative');
select public.vstudy_test_error('update public.focus_sessions set focused_minutes=planned_minutes+1','23514','focused minutes cannot exceed planned');
select public.vstudy_test_error('update public.focus_sessions set interruptions=-1','23514','interruptions cannot be negative');
select public.vstudy_test_error('update public.focus_sessions set interruptions=1001','23514','interruptions upper bound enforced');
select public.vstudy_test_error($q$update public.focus_sessions set started_at='-infinity'$q$,'23514','focus rejects infinite timestamps');
select public.vstudy_test_error($q$insert into public.flashcard_sessions(reviewed_at,reviewed_cards,remembered_cards) values(clock_timestamp()+interval '1 hour',20,10)$q$,'23514','future flashcard review insert rejected independently of client');
select public.vstudy_test_error($q$update public.flashcard_sessions set reviewed_at=clock_timestamp()+interval '1 hour'$q$,'23514','future flashcard review update rejected');
select public.vstudy_test_error('update public.flashcard_sessions set reviewed_cards=0,remembered_cards=0','23514','review count lower bound enforced');
select public.vstudy_test_error('update public.flashcard_sessions set reviewed_cards=10001','23514','review count upper bound enforced');
select public.vstudy_test_error('update public.flashcard_sessions set remembered_cards=-1','23514','remembered count cannot be negative');
select public.vstudy_test_error('update public.flashcard_sessions set remembered_cards=reviewed_cards+1','23514','remembered count cannot exceed reviews');
select public.vstudy_test_error($q$update public.flashcard_sessions set reviewed_at='-infinity'$q$,'23514','flashcard rejects infinite timestamps');
select public.vstudy_test_error($q$insert into public.focus_sessions(subject_id,started_at,planned_minutes,focused_minutes) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',clock_timestamp()-interval '1 hour',30,20)$q$,'23503','focus cannot reference foreign subject');
select public.vstudy_test_error($q$insert into public.flashcard_sessions(subject_id,reviewed_at,reviewed_cards,remembered_cards) values('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',clock_timestamp(),20,10)$q$,'23503','flashcard cannot reference foreign subject');
select public.vstudy_test_error($q$insert into public.focus_sessions(owner_id,started_at,planned_minutes,focused_minutes) values('22222222-2222-4222-8222-222222222222',clock_timestamp()-interval '1 hour',30,20)$q$,'42501','focus insert cannot spoof owner');
select public.vstudy_test_error($q$insert into public.flashcard_sessions(owner_id,reviewed_at,reviewed_cards,remembered_cards) values('22222222-2222-4222-8222-222222222222',clock_timestamp(),20,10)$q$,'42501','flashcard insert cannot spoof owner');
select public.vstudy_test_error($q$update public.focus_sessions set owner_id='22222222-2222-4222-8222-222222222222'$q$,'42501','focus owner cannot be changed');
select public.vstudy_test_error($q$update public.flashcard_sessions set owner_id='22222222-2222-4222-8222-222222222222'$q$,'42501','flashcard owner cannot be changed');
select public.vstudy_test_error('truncate public.study_goals','42501','goal TRUNCATE privilege revoked');
select public.vstudy_test_error('truncate public.focus_sessions','42501','focus TRUNCATE privilege revoked');
select public.vstudy_test_error('truncate public.flashcard_sessions','42501','flashcard TRUNCATE privilege revoked');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.vstudy_test_assert((select count(*)=0 from public.study_goals),'goals SELECT isolates owners');
select public.vstudy_test_assert((select count(*)=0 from public.focus_sessions),'focus SELECT isolates owners');
select public.vstudy_test_assert((select count(*)=0 from public.flashcard_sessions),'flashcard SELECT isolates owners');
with changed as (update public.study_goals set weekly_minutes=1800 returning *) select public.vstudy_test_assert((select count(*)=0 from changed),'cannot update foreign goals');
with changed as (update public.focus_sessions set interruptions=0 returning *) select public.vstudy_test_assert((select count(*)=0 from changed),'cannot update foreign focus records');
with changed as (update public.flashcard_sessions set remembered_cards=0 returning *) select public.vstudy_test_assert((select count(*)=0 from changed),'cannot update foreign flashcard records');
with removed as (delete from public.study_goals returning *) select public.vstudy_test_assert((select count(*)=0 from removed),'cannot delete foreign goals');
with removed as (delete from public.focus_sessions returning *) select public.vstudy_test_assert((select count(*)=0 from removed),'cannot delete foreign focus records');
with removed as (delete from public.flashcard_sessions returning *) select public.vstudy_test_assert((select count(*)=0 from removed),'cannot delete foreign flashcard records');
insert into public.study_goals(semester_start,semester_end) values('2026-08-01','2027-02-01');
insert into public.focus_sessions(started_at,planned_minutes,focused_minutes) values(clock_timestamp()-interval '1 hour',30,0);
insert into public.flashcard_sessions(reviewed_at,reviewed_cards,remembered_cards) values(clock_timestamp(),1,0);
with changed as (update public.focus_sessions set interruptions=1 returning *) select public.vstudy_test_assert((select count(*)=1 from changed),'owner can update focus record without subject');
with changed as (update public.flashcard_sessions set remembered_cards=1 returning *) select public.vstudy_test_assert((select count(*)=1 from changed),'owner can update flashcard record without subject');
with removed as (delete from public.study_goals returning *) select public.vstudy_test_assert((select count(*)=1 from removed),'owner can delete goals');
with removed as (delete from public.focus_sessions returning *) select public.vstudy_test_assert((select count(*)=1 from removed),'owner can delete focus record');
with removed as (delete from public.flashcard_sessions returning *) select public.vstudy_test_assert((select count(*)=1 from removed),'owner can delete flashcard record');

reset role;
-- Historical timestamps make cutoff assertions deterministic, without sleeping.
insert into public.quiz_chapters(id,owner_id,subject_id,title,position) values
 ('c1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Chương có đề',0),
 ('c2222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Chương trống',1),
 ('c3333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Môn khác',0),
 ('c4444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Chương riêng tư',0);
set local role service_role;
select set_config('stats.quiz_id',(public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Đề thống kê','',null,
 '[{"question":"Một?","options":["A","B","C","D"],"correct_option":1,"explanation":"Không được rò rỉ"},{"question":"Hai?","options":["A","B","C","D"],"correct_option":3}]',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','c1111111-1111-4111-8111-111111111111')->>'quiz_id'),true);
select set_config('stats.other_quiz_id',(public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Môn khác','',null,
 '[{"question":"Ba?","options":["A","B","C","D"],"correct_option":2}]',
 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','c3333333-3333-4333-8333-333333333333')->>'quiz_id'),true);
select set_config('stats.foreign_quiz_id',(public.create_generated_quiz('22222222-2222-4222-8222-222222222222','Riêng tư','',null,
 '[{"question":"Bốn?","options":["A","B","C","D"],"correct_option":0}]',
 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','c4444444-4444-4444-8444-444444444444')->>'quiz_id'),true);
select set_config('stats.q1',(select id::text from public.quiz_questions where quiz_id=current_setting('stats.quiz_id')::uuid and position=0),true);
select set_config('stats.q2',(select id::text from public.quiz_questions where quiz_id=current_setting('stats.quiz_id')::uuid and position=1),true);
insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions,submitted_at) values
 ('a1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,jsonb_build_object(current_setting('stats.q1'),0,current_setting('stats.q2'),0),0,2,'2020-01-01 10:00Z'),
 ('a2222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,jsonb_build_object(current_setting('stats.q1'),0,current_setting('stats.q2'),-1),0,2,'2020-01-01 13:00Z');
insert into public.quiz_practice_answers(owner_id,quiz_id,question_id,selected_option,answered_at) values
 ('11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q1')::uuid,1,'2020-01-01 11:00Z'),
 ('11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q2')::uuid,3,'2020-01-01 11:00Z'),
 ('11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q1')::uuid,1,'2020-01-01 13:00Z'),
 ('11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q2')::uuid,3,'2020-01-01 14:00Z');
insert into public.quiz_practice_answers(id,owner_id,quiz_id,question_id,selected_option,answered_at) values
 ('b1111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q1')::uuid,0,'2020-01-01 15:00Z'),
 ('b9999999-9999-4999-8999-999999999999','11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q1')::uuid,1,'2020-01-01 15:00Z');
insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions,submitted_at)
 select 'a3333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222',q.quiz_id,jsonb_build_object(q.id::text,0),1,1,'2020-01-01 12:00Z'
 from public.quiz_questions q where q.quiz_id=current_setting('stats.foreign_quiz_id')::uuid;
insert into public.quiz_practice_answers(owner_id,quiz_id,question_id,selected_option,answered_at)
 select '22222222-2222-4222-8222-222222222222',q.quiz_id,q.id,0,'2020-01-01 12:00Z'
 from public.quiz_questions q where q.quiz_id=current_setting('stats.foreign_quiz_id')::uuid;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.vstudy_test_assert((select count(*)=3 from public.get_chapter_mastery('2020-01-01 09:00Z')),'mastery lists only own chapters including empty chapters');
select public.vstudy_test_assert((select total_questions=2 and answered_questions=0 and correct_questions=0 from public.get_chapter_mastery('2020-01-01 09:00Z') where id='c1111111-1111-4111-8111-111111111111'),'mastery retains questions without historical answers');
select public.vstudy_test_assert((select total_questions=0 and answered_questions=0 and correct_questions=0 from public.get_chapter_mastery('2020-01-01 12:00Z') where id='c2222222-2222-4222-8222-222222222222'),'empty chapter returns zero counts');
select public.vstudy_test_assert((select total_questions=1 and answered_questions=0 and correct_questions=0 from public.get_chapter_mastery('2020-01-01 12:00Z') where id='c3333333-3333-4333-8333-333333333333'),'mastery groups question totals by chapter and subject');
select public.vstudy_test_assert((select answered_questions=2 and correct_questions=0 from public.get_chapter_mastery('2020-01-01 10:30Z') where id='c1111111-1111-4111-8111-111111111111'),'mastery cutoff excludes later practice feedback');
select public.vstudy_test_assert((select answered_questions=2 and correct_questions=2 from public.get_chapter_mastery('2020-01-01 12:00Z') where id='c1111111-1111-4111-8111-111111111111'),'latest correct practice improves mastery');
select public.vstudy_test_assert((select answered_questions=1 and correct_questions=1 from public.get_chapter_mastery('2020-01-01 13:00Z') where id='c1111111-1111-4111-8111-111111111111'),'latest completed attempt overrides old answers and unanswered is excluded');
select public.vstudy_test_assert((select answered_questions=2 and correct_questions=2 from public.get_chapter_mastery('2020-01-01 14:00Z') where id='c1111111-1111-4111-8111-111111111111'),'inclusive cutoff accepts practice at exact timestamp');
select public.vstudy_test_assert((select answered_questions=2 and correct_questions=2 from public.get_chapter_mastery('2020-01-01 15:00Z') where id='c1111111-1111-4111-8111-111111111111'),'mastery same-time history has deterministic tie break');
select public.vstudy_test_assert((select not bool_or(to_jsonb(m) ?| array['answers','correct_option','selected_option','explanation']) from public.get_chapter_mastery(clock_timestamp()) m),'mastery result never exposes grading keys or raw answers');
select public.vstudy_test_assert((select count(*)=7 from jsonb_object_keys((select to_jsonb(m) from public.get_chapter_mastery(clock_timestamp()) m limit 1))),'mastery API contains only seven documented aggregate fields');
select public.vstudy_test_error('select public.get_chapter_mastery(null)','22023','mastery rejects missing cutoff');
select public.vstudy_test_error($q$select public.get_chapter_mastery('infinity')$q$,'22023','mastery rejects infinite cutoff');
select public.vstudy_test_error('select * from public.quiz_answer_keys','42501','statistics does not grant direct grading-key access');
select public.vstudy_test_error('select * from public.quiz_practice_answers','42501','statistics does not grant direct practice-history access');

reset role;
set local role service_role;
insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions,submitted_at) values
 ('a4444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,jsonb_build_object(current_setting('stats.q1'),0,current_setting('stats.q2'),0),0,2,clock_timestamp()+interval '1 day');
insert into public.quiz_practice_answers(owner_id,quiz_id,question_id,selected_option,answered_at) values
 ('11111111-1111-4111-8111-111111111111',current_setting('stats.quiz_id')::uuid,current_setting('stats.q1')::uuid,0,clock_timestamp()+interval '2 days');
reset role;
set local role authenticated;
select public.vstudy_test_assert((select correct_questions=2 from public.get_chapter_mastery(clock_timestamp()+interval '3 days') where id='c1111111-1111-4111-8111-111111111111'),'future attempt and practice history excluded even with future cutoff');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.vstudy_test_assert((select count(*)=1 and min(correct_questions)=1 from public.get_chapter_mastery(clock_timestamp())),'mastery isolates foreign user attempts and practice');
select set_config('request.jwt.claim.sub','',true);
select public.vstudy_test_error('select public.get_chapter_mastery(clock_timestamp())','42501','mastery requires an authenticated user identity');
reset role;
set local role anon;
select public.vstudy_test_error('select * from public.study_goals','42501','anonymous goals access denied');
select public.vstudy_test_error('select * from public.focus_sessions','42501','anonymous focus access denied');
select public.vstudy_test_error('select * from public.flashcard_sessions','42501','anonymous flashcard access denied');
select public.vstudy_test_error('select public.get_chapter_mastery(clock_timestamp())','42501','anonymous mastery RPC denied');
reset role;
rollback;
