-- Vstudy: bo sung profiles cho tai khoan DA TON TAI trong Supabase Auth.
-- Cach dung: Supabase Dashboard -> SQL Editor -> New query -> dan ca file -> Run.
-- Chay bang role postgres cua SQL Editor, khong goi tu ung dung Flutter.
-- Co the chay lai: giu nguyen moi profile da co, khong xoa du lieu/doi quyen RLS.
-- Khong tao tai khoan, mat khau, xac nhan email hoac sua loi API key.

begin;

do $$
begin
  if to_regclass('auth.users') is null then
    raise exception 'Khong tim thay auth.users. Hay chay trong du an Supabase.';
  end if;
  if to_regclass('public.profiles') is null then
    raise exception 'Chua co public.profiles. Can cai schema Vstudy truoc khi chay file nay.';
  end if;
end;
$$;

with added as (
  insert into public.profiles (id, display_name)
  select
    u.id,
    left(coalesce(
      nullif(btrim(u.raw_user_meta_data ->> 'display_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
      ''
    ), 100)
  from auth.users u
  on conflict (id) do nothing
  returning id
)
select count(*) as profiles_added from added;

commit;

-- Neu auth_accounts = 0: tao tai khoan trong Authentication -> Users truoc.
-- Neu missing_profiles = 0: moi tai khoan Auth da co ho so.
select
  (select count(*) from auth.users) as auth_accounts,
  (select count(*) from public.profiles) as total_profiles,
  (select count(*) from auth.users u
    left join public.profiles p on p.id = u.id
    where p.id is null) as missing_profiles;
