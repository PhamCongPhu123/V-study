-- Disposable database only. Fixtures and helpers roll back.
begin;
create function public.ai_test_assert(p_condition boolean,p_message text) returns void
language plpgsql as $$ begin if p_condition is not true then raise exception 'FAIL: %',p_message; end if; raise notice 'PASS: %',p_message; end; $$;
create function public.ai_test_error(p_sql text,p_state text,p_message text) returns void
language plpgsql as $$ begin begin execute p_sql; exception when others then
 if sqlstate=p_state then raise notice 'PASS: %',p_message; return; end if;
 raise exception 'FAIL: % (expected %, got %: %)',p_message,p_state,sqlstate,sqlerrm;
 end; raise exception 'FAIL: % (unexpected success)',p_message; end; $$;
grant execute on function public.ai_test_assert(boolean,text),public.ai_test_error(text,text,text) to authenticated,anon,service_role;
insert into auth.users(id,raw_user_meta_data) values
 ('11111111-1111-4111-8111-111111111111','{}'),('22222222-2222-4222-8222-222222222222','{}');
insert into public.documents(id,owner_id,title,storage_path,mime_type,size_bytes) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Tài liệu A','11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a.txt','text/plain',100),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Tài liệu B','22222222-2222-4222-8222-222222222222/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/b.txt','text/plain',100),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','11111111-1111-4111-8111-111111111111','Tài liệu lớn','11111111-1111-4111-8111-111111111111/cccccccc-cccc-4ccc-8ccc-cccccccccccc/c.pdf','application/pdf',10485760);
set local role service_role;
select public.save_ai_artifact('a0000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','summary','Tóm tắt A',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']::uuid[],
 '{"brief":["Ý chính"],"sections":[{"title":"Chính","points":["Ý"]}],"keywords":["Từ"],"mind_map":[{"title":"Nhánh","points":["Ý"]}]}',repeat('a',64));
select public.save_ai_artifact('a0000000-0000-4000-8000-000000000002','22222222-2222-4222-8222-222222222222','summary','Tóm tắt B',
 array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']::uuid[],
 '{"brief":["Ý chính"],"sections":[],"keywords":[],"mind_map":[]}',repeat('b',64));
select public.ai_test_error($q$select public.save_ai_artifact('a0000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','summary','Foreign',
 array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']::uuid[],'{}',repeat('c',64))$q$,'22023','AI artifact cannot reference foreign documents');
select public.ai_test_error($q$select public.save_ai_artifact('a0000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','summary','Duplicate',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']::uuid[],'{}',repeat('c',64))$q$,'22023','AI artifact rejects duplicate source IDs');
select public.ai_test_error($q$select public.save_ai_artifact('a0000000-0000-4000-8000-000000000003','11111111-1111-4111-8111-111111111111','summary','Oversized',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc']::uuid[],'{}',repeat('c',64))$q$,'22023','AI aggregate source limit enforced independently in database');
select public.ai_test_error($q$select public.save_ai_artifact('a0000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111','summary','Changed',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']::uuid[],'{}',repeat('c',64))$q$,'P0409','AI retry identity rejects changed fingerprint');
select public.ai_test_error($q$select public.save_ai_artifact('a0000000-0000-4000-8000-000000000001','22222222-2222-4222-8222-222222222222','summary','Other owner',
 array['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']::uuid[],'{}',repeat('a',64))$q$,'P0409','AI retry never returns another owner result');
reset role;
select public.ai_test_assert((select count(*)=2 from public.ai_artifacts),'invalid artifacts create no partial rows');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.ai_test_assert((select count(*)=1 from public.ai_artifacts),'AI history SELECT isolates owners');
select public.ai_test_assert((select source_titles=array['Tài liệu A'] from public.ai_artifacts),'AI sources use titles read from owned metadata');
update public.ai_artifacts set feedback=1;
select public.ai_test_assert((select feedback=1 from public.ai_artifacts),'owner can rate generated content');
update public.ai_artifacts set feedback=null;
select public.ai_test_assert((select feedback is null from public.ai_artifacts),'owner can remove a rating');
select public.ai_test_error('update public.ai_artifacts set feedback=2','23514','invalid AI feedback is rejected');
select public.ai_test_error('update public.ai_artifacts set content=''{}''','42501','client cannot edit AI content or grading data');
select public.ai_test_error('update public.ai_artifacts set created_at=now()','42501','AI creation timestamp is immutable');
select public.ai_test_error('update public.ai_artifacts set owner_id=''22222222-2222-4222-8222-222222222222''','42501','AI artifact owner is immutable');
select public.ai_test_error('truncate public.ai_artifacts','42501','AI artifact TRUNCATE privilege revoked');
select public.ai_test_error($q$select public.save_ai_artifact(gen_random_uuid(),'11111111-1111-4111-8111-111111111111','worksheet','Forged','{}','{"questions":[{}]}',repeat('a',64))$q$,'42501','client cannot forge generated content through service RPC');
with changed as (update public.ai_artifacts set feedback=-1 where id='a0000000-0000-4000-8000-000000000002' returning id)
select public.ai_test_assert((select count(*)=0 from changed),'cannot rate another owner artifact');
with removed as (delete from public.ai_artifacts where id='a0000000-0000-4000-8000-000000000002' returning id)
select public.ai_test_assert((select count(*)=0 from removed),'cannot delete another owner artifact');
reset role;
set local role service_role;
select set_config('ai.quiz',(public.save_ai_artifact('a0000000-0000-4000-8000-000000000004','11111111-1111-4111-8111-111111111111','quiz','40 câu',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']::uuid[],'{"malicious_answer_key":"must be removed"}',repeat('d',64),'Toán',
 (select jsonb_agg(jsonb_build_object('question','Câu '||i,'options',jsonb_build_array('A','B','C','D'),'correct_option',1,'explanation','B đúng','hint','Đọc kỹ dữ kiện.')) from generate_series(1,40) i))->>'quiz_id'),true);
select public.ai_test_assert((select count(*)=40 from public.quiz_questions where quiz_id=current_setting('ai.quiz')::uuid),'AI can save a 40 question official quiz');
select public.ai_test_assert((select content='{}'::jsonb from public.ai_artifacts where id='a0000000-0000-4000-8000-000000000004'),'official quiz artifact strips answer data');
select public.save_ai_artifact('a0000000-0000-4000-8000-000000000004','11111111-1111-4111-8111-111111111111','quiz','40 câu',
 array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa']::uuid[],'{}',repeat('d',64));
select public.ai_test_assert((select count(*)=1 from public.quizzes),'retry of saved quiz does not create duplicate quiz');
select public.ai_test_error($q$select public.create_generated_quiz('11111111-1111-4111-8111-111111111111','41','Toán',null,
 (select jsonb_agg(jsonb_build_object('question','Q '||i,'options',jsonb_build_array('A','B','C','D'),'correct_option',0)) from generate_series(1,41) i))$q$,'P0001','official quiz rejects more than 40 questions');
reset role;
set local role authenticated;
select public.ai_test_assert((select count(*)=40 from public.quiz_questions where hint='Đọc kỹ dữ kiện.'),'official quiz stores readable learning hints without exposing keys');
select public.ai_test_assert((public.submit_quiz_attempt(current_setting('ai.quiz')::uuid,
 (select jsonb_object_agg(id::text,1) from public.quiz_questions where quiz_id=current_setting('ai.quiz')::uuid),
 'a0000000-0000-4000-8000-000000000005',false,'exam')->>'total_questions')::integer=40,'40 question quiz uses server grading successfully');
select public.ai_test_error('select * from public.quiz_answer_keys','42501','AI tools do not expose private official grading keys');
delete from public.ai_artifacts where id='a0000000-0000-4000-8000-000000000004';
select public.ai_test_assert((select count(*)=1 from public.quizzes),'deleting AI history keeps its official quiz');
delete from public.documents where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select public.ai_test_assert((select source_titles=array['Tài liệu A'] from public.ai_artifacts),'saved summary retains source title snapshot after document deletion');
reset role;
set local role anon;
select public.ai_test_error('select * from public.ai_artifacts','42501','anonymous cannot read generated content');
select public.ai_test_error('update public.ai_artifacts set feedback=1','42501','anonymous cannot rate generated content');
reset role;
rollback;
