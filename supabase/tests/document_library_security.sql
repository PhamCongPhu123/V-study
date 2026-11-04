-- Disposable PostgreSQL only: fixtures are rolled back.
begin;
create function public.document_test_assert(ok boolean, message text) returns void
language plpgsql as $$ begin
  if ok is not true then raise exception 'FAIL: %',message; end if;
  raise notice 'PASS: %',message;
end; $$;
create function public.document_test_error(statement text, expected text, message text) returns void
language plpgsql as $$ begin
  begin execute statement;
  exception when others then
    if sqlstate=expected then raise notice 'PASS: %',message; return; end if;
    raise exception 'FAIL: % (expected %, got %)',message,expected,sqlstate;
  end;
  raise exception 'FAIL: % (unexpected success)',message;
end; $$;
grant execute on function public.document_test_assert(boolean,text),public.document_test_error(text,text,text) to authenticated,anon;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
insert into public.subjects(id,owner_id,name) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Toán'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Môn riêng');
insert into public.documents(id,owner_id,title,storage_path,mime_type,size_bytes) values
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','11111111-1111-4111-8111-111111111111','Ghi chú','11111111-1111-4111-8111-111111111111/dddddddd-dddd-4ddd-8ddd-dddddddddddd/notes.txt','text/plain',20),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','22222222-2222-4222-8222-222222222222','Riêng tư','22222222-2222-4222-8222-222222222222/eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee/notes.txt','text/plain',20);
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.document_test_assert((select count(*)=1 and bool_and(not is_favorite and subject_id is null) from public.documents),'document defaults preserve private library');
update public.documents set is_favorite=true,subject_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
select public.document_test_assert((select is_favorite and subject_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' from public.documents),'owner can favorite and classify own document');
select public.document_test_error($s$update public.documents set subject_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'$s$,'23503','document cannot link foreign subject');
select public.document_test_error($s$update public.documents set storage_path='bad'$s$,'42501','document object path is immutable');
select public.document_test_error($s$update public.documents set size_bytes=1$s$,'42501','document byte count is immutable');
select public.document_test_error($s$update public.documents set owner_id='22222222-2222-4222-8222-222222222222'$s$,'42501','document owner is immutable');
select public.document_test_error($s$update public.documents set mime_type='application/pdf'$s$,'42501','document media type is immutable');
with changed as (update public.documents set is_favorite=true where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' returning id)
select public.document_test_assert((select count(*)=0 from changed),'favorite update cannot affect foreign document');
delete from public.subjects where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select public.document_test_assert((select subject_id is null and is_favorite and owner_id=auth.uid() from public.documents),'deleting subject preserves document ownership and favorite');
select public.document_test_error($s$truncate public.documents$s$,'42501','document truncate remains denied');
reset role;
set local role anon;
select public.document_test_error($s$select is_favorite from public.documents$s$,'42501','anonymous document metadata remains private');
select public.document_test_error($s$update public.documents set is_favorite=true$s$,'42501','anonymous favorite update denied');
rollback;
