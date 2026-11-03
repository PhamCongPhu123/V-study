-- Fresh additive feature checks; all fixtures roll back. Never production.
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
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.subjects(id,name) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Triết học'),('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Pháp luật');
insert into public.quiz_chapters(id,subject_id,title,position) values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Chương 1',0);
select public.vstudy_test_error($q$insert into public.quiz_chapters(owner_id,subject_id,title) values('22222222-2222-4222-8222-222222222222','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Spoof')$q$,'42501','chapter owner cannot be spoofed');
select public.vstudy_test_error('truncate public.quiz_chapters','42501','chapter TRUNCATE privilege revoked');
select public.vstudy_test_assert((public.create_quiz_chapter('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','  Chương mới  ')->>'title')='Chương mới','chapter RPC trims title');
select public.vstudy_test_assert((public.create_quiz_chapter('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Chương tiếp')->>'position')::integer=1,'chapter RPC allocates next position');
select public.vstudy_test_error($q$select public.create_quiz_chapter('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','   ')$q$,'22023','chapter RPC rejects empty title');
select public.vstudy_test_error('select * from public.quiz_practice_answers','42501','practice history protected from direct client access');
reset role;
set local role service_role;
select set_config('quiz.test_id',(public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Đề 1','Triết',null,
 '[{"question":"Một?","options":["A","B","C","D"],"correct_option":1,"explanation":"B đúng"},{"question":"Hai?","options":["A","B","C","D"],"correct_option":3,"explanation":"D đúng"}]',
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',25,'easy')->>'quiz_id'),true);
select public.vstudy_test_error($q$select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Bad','',null,'[{"question":"Q","options":["A","B","C","D"],"correct_option":0}]','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$q$,'23503','chapter must belong to chosen subject');
select public.vstudy_test_error($q$select public.create_generated_quiz('22222222-2222-4222-8222-222222222222','Bad','',null,'[{"question":"Q","options":["A","B","C","D"],"correct_option":0}]','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$q$,'23503','generated quiz cannot use foreign subject');
select public.vstudy_test_error($q$select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Bad','',null,'[{"question":"Q","options":["A","B","C","D"],"correct_option":0}]',null,null,0)$q$,'23514','quiz duration validated in database');
reset role;
set local role authenticated;
select public.vstudy_test_assert((select count(*)=1 from public.quizzes),'invalid quiz metadata creates no partial quiz');
select public.vstudy_test_assert((select duration_minutes=25 and difficulty='easy' from public.quizzes),'quiz metadata persisted');
select public.vstudy_test_assert((select question_count=2 from public.list_quiz_chapters('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),'chapter RPC derives actual question count');
select public.vstudy_test_assert((select count(*)=0 from public.list_wrong_quiz_answers()),'unanswered questions do not expose answer keys');
select public.vstudy_test_error(format('select public.check_practice_answer(%L,%L,4)',current_setting('quiz.test_id'),(select id from public.quiz_questions where position=0)),'22023','practice validates option range');
select public.vstudy_test_assert((public.check_practice_answer(current_setting('quiz.test_id')::uuid,(select id from public.quiz_questions where position=0),0)->>'correct_option')::integer=1,'practice feedback grades private answer key');
select public.vstudy_test_assert((select count(*)=1 from public.list_wrong_quiz_answers()),'wrong practice answer enters mistake bank');
select public.vstudy_test_assert((select count(*)=0 from public.list_wrong_quiz_answers('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')),'mistake bank respects subject filter');
select public.check_practice_answer(current_setting('quiz.test_id')::uuid,(select id from public.quiz_questions where position=0),1);
select public.vstudy_test_assert((select count(*)=0 from public.list_wrong_quiz_answers()),'latest correct practice answer clears mistake');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L)',current_setting('quiz.test_id'),'{}','dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'22023','normal submit still rejects missing answers');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L,true)',current_setting('quiz.test_id'),'{"99999999-9999-4999-8999-999999999999":0}','dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'22023','timed submit rejects foreign question ids');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L,true)',current_setting('quiz.test_id'),(select jsonb_object_agg(id::text,-1) from public.quiz_questions),'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'22023','client cannot send sentinel option directly');
select public.submit_quiz_attempt(current_setting('quiz.test_id')::uuid,
 (select jsonb_object_agg(id::text,1) from public.quiz_questions where position=0),'dddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
select public.vstudy_test_assert((select correct_count=1 and total_questions=2 from public.quiz_attempts),'timed missing answer scored incorrect');
select public.vstudy_test_assert((select count(*)=1 from jsonb_array_elements(public.get_quiz_attempt('dddddddd-dddd-4ddd-8ddd-dddddddddddd')->'review') r where (r->>'selected_option')::integer=-1),'attempt replay marks unanswered option');
select public.submit_quiz_attempt(current_setting('quiz.test_id')::uuid,
 (select jsonb_object_agg(id::text,1) from public.quiz_questions where position=0),'dddddddd-dddd-4ddd-8ddd-dddddddddddd',true);
select public.vstudy_test_assert((select count(*)=1 from public.quiz_attempts),'timed submission retry is idempotent');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L,true)',current_setting('quiz.test_id'),'{}','dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'22023','timed retry rejects changed answers');
select public.vstudy_test_assert((select count(*)=1 from public.list_wrong_quiz_answers()),'latest full submission adds unanswered to mistake bank');
select public.check_practice_answer(current_setting('quiz.test_id')::uuid,(select id from public.quiz_questions where position=1),3);
select public.vstudy_test_assert((select count(*)=0 from public.list_wrong_quiz_answers()),'correct practice resolves previous timed mistake');
select public.submit_quiz_attempt(current_setting('quiz.test_id')::uuid,
 (select jsonb_object_agg(id::text,0) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',false,'exam');
select public.vstudy_test_assert((select count(*)=2 from public.list_wrong_quiz_answers()),'new full attempt overrides earlier correct practice');
select public.vstudy_test_assert((select count(*)=2 from public.quiz_attempts),'practice feedback does not forge completed attempts');
select public.vstudy_test_assert((select mode='exam' from public.quiz_attempts where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),'completed exam persists mode');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L,false,%L)',current_setting('quiz.test_id'),(select jsonb_object_agg(id::text,0) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','practice'),'22023','attempt retry cannot change exam mode');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.vstudy_test_assert((select count(*)=0 from public.quiz_chapters),'chapter RLS isolates accounts');
select public.vstudy_test_error($q$select public.create_quiz_chapter('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Foreign')$q$,'42501','chapter RPC denies foreign subject');
select public.vstudy_test_assert((select count(*)=0 from public.list_quiz_chapters('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),'chapter RPC isolates accounts');
select public.vstudy_test_assert((select count(*)=0 from public.list_wrong_quiz_answers()),'mistake RPC isolates accounts');
select public.vstudy_test_error($q$select public.get_quiz_attempt('dddddddd-dddd-4ddd-8ddd-dddddddddddd')$q$,'42501','cannot replay another user attempt');
select public.vstudy_test_error(format('select public.check_practice_answer(%L,%L,0)',current_setting('quiz.test_id'),'99999999-9999-4999-8999-999999999999'),'42501','cannot practice another user quiz');
reset role;
set local role anon;
select public.vstudy_test_error('select public.list_wrong_quiz_answers()','42501','anonymous mistake RPC denied');
select public.vstudy_test_error($q$select public.get_quiz_attempt('dddddddd-dddd-4ddd-8ddd-dddddddddddd')$q$,'42501','anonymous attempt replay denied');
select public.vstudy_test_error($q$select public.check_practice_answer(gen_random_uuid(),gen_random_uuid(),0)$q$,'42501','anonymous practice feedback denied');
reset role;
rollback;
