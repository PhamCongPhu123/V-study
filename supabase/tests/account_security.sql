-- Disposable PostgreSQL test database only; never run on a hosted project.
begin;
create function public.account_test_assert(p_condition boolean,p_message text) returns void
language plpgsql as $$ begin
  if p_condition is not true then raise exception 'FAIL: %',p_message; end if;
  raise notice 'PASS: %',p_message;
end; $$;
create function public.account_test_error(p_sql text,p_state text,p_message text) returns void
language plpgsql as $$ begin
  begin execute p_sql;
  exception when others then
    if sqlstate=p_state then raise notice 'PASS: %',p_message; return; end if;
    raise exception 'FAIL: % (expected %, got %)',p_message,p_state,sqlstate;
  end;
  raise exception 'FAIL: % (unexpected success)',p_message;
end; $$;
grant execute on function public.account_test_assert(boolean,text),public.account_test_error(text,text,text)
  to authenticated,anon;

insert into auth.users(id,raw_user_meta_data) values
 ('11111111-1111-4111-8111-111111111111','{"display_name":"An"}'),
 ('22222222-2222-4222-8222-222222222222','{"display_name":"Bình"}');
select public.account_test_assert((select class_name='' and major='' and birth_date is null
  and avatar_key='student' and dark_profile=false and study_reminders=true
  from public.profiles where id='11111111-1111-4111-8111-111111111111'),'new profiles receive safe account defaults');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.account_test_assert((select count(*)=1 from public.profiles),'account profile remains owner-private');
update public.profiles set display_name='Nguyễn An',class_name='CNTT1',major='Công nghệ thông tin',
  birth_date='2004-06-15',avatar_key='book',daily_goal_minutes=120
  where id='11111111-1111-4111-8111-111111111111';
select public.account_test_assert((select display_name='Nguyễn An' and class_name='CNTT1'
  and major='Công nghệ thông tin' and birth_date=date '2004-06-15' and avatar_key='book'
  and daily_goal_minutes=120 from public.profiles),'owner can save complete account details');
update public.profiles set dark_profile=true,study_reminders=false;
select public.account_test_assert((select dark_profile and not study_reminders
  and display_name='Nguyễn An' and daily_goal_minutes=120 and avatar_key='book' from public.profiles),
  'preferences save without overwriting profile details or goals');
update public.profiles set display_name='An mới',daily_goal_minutes=150;
select public.account_test_assert((select class_name='CNTT1' and major='Công nghệ thông tin'
  and birth_date=date '2004-06-15' and avatar_key='book' and dark_profile and not study_reminders
  from public.profiles),'existing goal updates preserve new account fields');
update public.profiles set birth_date=null;
select public.account_test_assert((select birth_date is null from public.profiles),'birth date can be cleared');
with changed as (update public.profiles set class_name='Hacked'
  where id='22222222-2222-4222-8222-222222222222' returning id)
select public.account_test_assert((select count(*)=0 from changed),'cannot update another account');
select public.account_test_error($sql$update public.profiles set class_name=repeat('x',81)$sql$,'23514','class length is enforced');
select public.account_test_error($sql$update public.profiles set major=repeat('x',121)$sql$,'23514','major length is enforced');
select public.account_test_error($sql$update public.profiles set avatar_key='https://untrusted.example/photo'$sql$,'23514','avatar is restricted to known presets');
select public.account_test_error($sql$update public.profiles set birth_date=current_date+1$sql$,'23514','future birth date is rejected');
select public.account_test_error($sql$update public.profiles set birth_date='1899-12-31'$sql$,'23514','birth date before 1900 is rejected');
select public.account_test_error($sql$update public.profiles set birth_date='infinity'$sql$,'23514','infinite birth date is rejected');
select public.account_test_error($sql$update public.profiles set dark_profile=null$sql$,'23502','dark mode cannot be null');
select public.account_test_error($sql$update public.profiles set study_reminders=null$sql$,'23502','reminder preference cannot be null');
select public.account_test_error($sql$update public.profiles set created_at=now()$sql$,'42501','account cannot change creation time');
select public.account_test_error($sql$update public.profiles set id='22222222-2222-4222-8222-222222222222'$sql$,'42501','account cannot change identity');
reset role;
select public.account_test_assert((select class_name='' and not dark_profile from public.profiles
  where id='22222222-2222-4222-8222-222222222222'),'other account stays unchanged');
set local role anon;
select public.account_test_error($sql$select birth_date from public.profiles$sql$,'42501','anonymous clients cannot read private birth dates');
select public.account_test_error($sql$update public.profiles set class_name='Anonymous'$sql$,'42501','anonymous clients cannot edit accounts');
reset role;
rollback;
