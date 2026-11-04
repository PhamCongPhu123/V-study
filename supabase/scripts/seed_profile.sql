-- Tao san ho so Vstudy, khong can su dung form dang ky trong ung dung.
-- 1. Supabase -> Authentication -> Users -> Add user -> Create new user.
--    Nhap email/mat khau cua ban va bat Auto Confirm User neu co tuy chon.
-- 2. Sua v_email ben duoi thanh DUNG email vua tao; sua ten/muc tieu tuy y.
-- 3. Dan ca file vao SQL Editor va Run bang role postgres.
-- Khong dat mat khau trong SQL. File chi cap nhat ho so cua email duoc chon.

begin;
do $$
declare
  v_email text := 'CHANGE_ME@example.com'; -- THAY BANG EMAIL TAI KHOAN CUA BAN.
  v_display_name text := 'Phú';
  v_daily_goal_minutes integer := 180;
  v_user_id uuid;
begin
  if lower(btrim(v_email)) = 'change_me@example.com' then
    raise exception 'Hay sua v_email thanh email da tao trong Authentication -> Users.';
  end if;

  select id into v_user_id from auth.users
  where lower(email) = lower(btrim(v_email));

  if v_user_id is null then
    raise exception 'Chua co tai khoan Auth voi email nay. Tao tai khoan trong Authentication -> Users -> Add user truoc.';
  end if;

  insert into public.profiles (id, display_name, daily_goal_minutes, timezone)
  values (v_user_id, btrim(v_display_name), v_daily_goal_minutes, 'Asia/Ho_Chi_Minh')
  on conflict (id) do update set
    display_name = excluded.display_name,
    daily_goal_minutes = excluded.daily_goal_minutes,
    timezone = excluded.timezone;

  raise notice 'Da luu ho so. Ban co the dang nhap bang email va mat khau da tao trong Authentication.';
end;
$$;
commit;
