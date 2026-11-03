-- Run after migrations. Fixtures and helper functions are rolled back.
begin;
create function public.vstudy_test_assert(p_condition boolean,p_message text) returns void
language plpgsql as $$ begin if p_condition is not true then raise exception 'FAIL: %',p_message; end if; raise notice 'PASS: %',p_message; end; $$;
create function public.vstudy_test_error(p_sql text,p_state text,p_message text) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlstate = p_state then raise notice 'PASS: %',p_message; return; end if;
    raise exception 'FAIL: % (expected %, got %: %)',p_message,p_state,sqlstate,sqlerrm;
  end;
  raise exception 'FAIL: % (operation unexpectedly succeeded)',p_message;
end;
$$;
grant execute on function public.vstudy_test_assert(boolean,text),public.vstudy_test_error(text,text,text) to authenticated,anon,service_role;
insert into auth.users(id,raw_user_meta_data) values
 ('11111111-1111-4111-8111-111111111111','{"display_name":"An"}'),
 ('22222222-2222-4222-8222-222222222222','{"display_name":"Bình"}');
select public.vstudy_test_assert((select display_name='An' from public.profiles where id='11111111-1111-4111-8111-111111111111'),'signup creates profile from metadata');
insert into auth.users(id,raw_user_meta_data) values
 ('99999999-9999-4999-8999-999999999999','{"full_name":"Tên Google","name":"Tên dự phòng"}');
select public.vstudy_test_assert((select display_name='Tên Google' from public.profiles where id='99999999-9999-4999-8999-999999999999'),'Google OAuth metadata falls back to full_name before name');
delete from auth.users where id='99999999-9999-4999-8999-999999999999';
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.vstudy_test_assert((select count(*)=1 from public.profiles),'profiles isolated by RLS');
insert into public.subjects(id,name) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Giải tích');
select public.vstudy_test_error($sql$insert into public.subjects(owner_id,name) values('22222222-2222-4222-8222-222222222222','Spoof')$sql$,'42501','cannot insert another owner');
select public.vstudy_test_error($sql$truncate table public.subjects$sql$,'42501','RLS cannot be bypassed using TRUNCATE');
select public.vstudy_test_error($sql$update public.profiles set created_at=now()$sql$,'42501','profile creation time is immutable');
select public.vstudy_test_error($sql$update public.profiles set id='22222222-2222-4222-8222-222222222222'$sql$,'42501','profile identity is immutable');
select count(*) from public.create_study_event(
 '{"title":"Ôn tập","kind":"self_study","starts_at":"2026-11-03T12:00:00Z","ends_at":"2026-11-03T13:00:00Z","subject_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}',
 '["Đọc chương 1","Làm bài tập"]',2);
select public.vstudy_test_assert((select count(*)=3 from public.study_events),'weekly events materialized');
select public.vstudy_test_assert((select count(*)=6 from public.event_tasks),'checklists copied for each occurrence');
select public.vstudy_test_assert((select count(distinct series_id)=1 from public.study_events),'weekly events share series id');
select public.vstudy_test_error($sql$select * from public.create_study_event('{"title":"Invalid","kind":"self_study","starts_at":"2026-11-03T13:00:00Z","ends_at":"2026-11-03T12:00:00Z"}')$sql$,'23514','event end must not precede start');
select public.vstudy_test_error($sql$select * from public.create_study_event('{"title":"Invalid","kind":"class","starts_at":"2026-11-03T12:00:00Z","ends_at":"2026-11-03T13:00:00Z"}','[""]',1)$sql$,'23514','invalid checklist rolls back all occurrences');
select public.vstudy_test_assert((select count(*)=3 from public.study_events),'failed recurring insert is atomic');
insert into public.documents(id,title,storage_path,mime_type,size_bytes) values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','Tài liệu','11111111-1111-4111-8111-111111111111/dddddddd-dddd-4ddd-8ddd-dddddddddddd/lesson.txt','text/plain',10);
insert into storage.objects(bucket_id,name) values('study-documents','11111111-1111-4111-8111-111111111111/dddddddd-dddd-4ddd-8ddd-dddddddddddd/lesson.txt');
select public.vstudy_test_error($sql$insert into storage.objects(bucket_id,name) values('study-documents','22222222-2222-4222-8222-222222222222/x/a.pdf')$sql$,'42501','cannot upload into another user folder');
select public.vstudy_test_error($sql$insert into public.documents(title,storage_path,mime_type,size_bytes) values('Bad','11111111-1111-4111-8111-111111111111/x/file.txt','text/plain',5)$sql$,'23514','document path must bind document id');
select public.vstudy_test_error($sql$insert into public.documents(id,title,storage_path,mime_type,size_bytes) values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Bad','11111111-1111-4111-8111-111111111111/cccccccc-cccc-4ccc-8ccc-cccccccccccc/..%2F..%2Fsecret','text/plain',5)$sql$,'23514','encoded traversal filename rejected');
select public.vstudy_test_error($sql$select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Cheat','',null,'[]')$sql$,'42501','client cannot create generated quiz or answer key');
select public.vstudy_test_error($sql$select * from public.quiz_answer_keys$sql$,'42501','client cannot read answer keys');
select public.vstudy_test_error($sql$insert into public.quiz_attempts(id,owner_id,quiz_id,answers,correct_count,total_questions) values(gen_random_uuid(),'11111111-1111-4111-8111-111111111111',gen_random_uuid(),'{}',30,30)$sql$,'42501','client cannot forge score');
select public.vstudy_test_error($sql$select public.save_chat_turn('11111111-1111-4111-8111-111111111111',null,'x','qa',null,'hello','answer')$sql$,'42501','client cannot forge AI turn');
select public.vstudy_test_error($sql$select public.acquire_ai_request('11111111-1111-4111-8111-111111111111','ai-chat',null)$sql$,'42501','AI quota only service role');

-- The server uses privileged role only after explicit auth.getUser validation.
reset role;
set local role service_role;
select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Toán','Giải tích','dddddddd-dddd-4ddd-8ddd-dddddddddddd',
 '[{"question":"1+1?","options":["1","2","3","4"],"correct_option":1,"explanation":"1+1=2"},{"question":"2+2?","options":["1","2","3","4"],"correct_option":3,"explanation":"2+2=4"}]');
select public.vstudy_test_error($sql$select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','Invalid','',null,'[{"question":"Q","options":["A","B"],"correct_option":0}]')$sql$,'23514','generated quiz schema validated in DB');
select public.vstudy_test_assert((select count(*)=1 from public.quizzes),'invalid quiz creation is atomic');
select set_config('vstudy.test_quiz_id',(select id::text from public.quizzes limit 1),true);
select public.vstudy_test_error($sql$select public.create_generated_quiz('22222222-2222-4222-8222-222222222222','Cross-owner doc','','dddddddd-dddd-4ddd-8ddd-dddddddddddd','[{"question":"Q","options":["A","B","C","D"],"correct_option":0}]')$sql$,'23503','quiz cannot link another owner document');
select public.vstudy_test_error($sql$select public.save_chat_turn('11111111-1111-4111-8111-111111111111',null,'Failure','qa',null,'Hello','')$sql$,'23514','failed assistant response rolls back user message');
select public.vstudy_test_assert((select count(*)=0 from public.chat_threads),'failed chat turn has no thread');
select public.save_chat_turn('11111111-1111-4111-8111-111111111111',null,'Giải thích','qa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','Đạo hàm là gì?','Đạo hàm biểu diễn tốc độ thay đổi.');
select public.vstudy_test_assert((select count(*)=2 from public.chat_messages),'successful AI turn saves exactly two messages');
select public.acquire_ai_request('11111111-1111-4111-8111-111111111111','ai-chat',null);
select public.vstudy_test_error($sql$select public.acquire_ai_request('11111111-1111-4111-8111-111111111111','ai-chat',null)$sql$,'P0409','concurrent AI request blocked across isolates');
select public.release_ai_request(id) from public.ai_requests;
select public.acquire_ai_request('11111111-1111-4111-8111-111111111111','ai-chat',null);
select public.vstudy_test_assert((select count(*)=2 from public.ai_requests),'released lease permits next request');
select public.release_ai_request(id) from public.ai_requests;
insert into public.ai_requests(owner_id,scope,released_at)
select '22222222-2222-4222-8222-222222222222','generate-quiz',clock_timestamp() from generate_series(1,30);
select public.vstudy_test_error($sql$select public.acquire_ai_request('22222222-2222-4222-8222-222222222222','generate-quiz',null)$sql$,'P0429','AI quota applies after 30 requests per minute');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L)',(select id from public.quizzes limit 1),'{}','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),'22023','incomplete quiz submission rejected');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L::jsonb,%L)',(select id from public.quizzes limit 1),(select jsonb_object_agg(id::text,'"1"'::jsonb) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),'22023','string answers rejected');
select public.submit_quiz_attempt((select id from public.quizzes limit 1),(select jsonb_object_agg(id::text,case when position=0 then 1 else 0 end) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
select public.vstudy_test_assert((select correct_count=1 and total_questions=2 from public.quiz_attempts),'quiz graded server-side');
select public.vstudy_test_assert(jsonb_array_length(public.submit_quiz_attempt((select id from public.quizzes limit 1),(select jsonb_object_agg(id::text,case when position=0 then 1 else 0 end) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')->'review')=2,'submission retry returns review');
select public.vstudy_test_assert((select count(*)=1 from public.quiz_attempts),'submission retries are idempotent');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L::jsonb,%L)',(select id from public.quizzes limit 1),(select jsonb_object_agg(id::text,3) from public.quiz_questions),'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),'22023','attempt id cannot be reused with changed answers');

-- A different authenticated user sees none of the first user's private records.
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.vstudy_test_assert((select count(*)=0 from public.subjects),'subjects isolated');
select public.vstudy_test_assert((select count(*)=0 from public.study_events),'events isolated');
select public.vstudy_test_assert((select count(*)=0 from public.event_tasks),'checklists isolated');
select public.vstudy_test_assert((select count(*)=0 from public.documents),'documents isolated');
select public.vstudy_test_assert((select count(*)=0 from public.quizzes),'quizzes isolated');
select public.vstudy_test_assert((select count(*)=0 from public.quiz_questions),'questions isolated');
select public.vstudy_test_assert((select count(*)=0 from public.quiz_attempts),'attempts isolated');
select public.vstudy_test_error(format('select public.submit_quiz_attempt(%L,%L,%L)',current_setting('vstudy.test_quiz_id'),'{}','ffffffff-ffff-4fff-8fff-ffffffffffff'),'42501','grading RPC denies another owner quiz');
select public.vstudy_test_assert((select count(*)=0 from public.chat_threads),'chat threads isolated');
select public.vstudy_test_assert((select count(*)=0 from public.chat_messages),'chat messages isolated');
select public.vstudy_test_assert((select count(*)=0 from storage.objects),'document objects isolated');
select public.vstudy_test_error($sql$insert into public.study_sessions(subject_id,started_at,duration_minutes) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',now(),60)$sql$,'23503','cross-user subject association forbidden');
select public.vstudy_test_error($sql$insert into public.event_tasks(event_id,title) values((select id from public.study_events limit 1),'x')$sql$,'23502','hidden parent cannot be linked');
reset role;
set local role anon;
select public.vstudy_test_error($sql$select * from public.profiles$sql$,'42501','anonymous profile access denied');
select public.vstudy_test_error($sql$select * from public.documents$sql$,'42501','anonymous document access denied');
select public.vstudy_test_error($sql$select public.submit_quiz_attempt(gen_random_uuid(),'{}',gen_random_uuid())$sql$,'42501','anonymous grading denied');
reset role;
rollback;
