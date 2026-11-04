-- Chi bo nhan MAU trong du lieu khoi tao, KHONG xoa ban ghi.
-- Sua v_email thanh email cua ban roi chay CA FILE trong SQL Editor (postgres).
-- Lich su hoc minh hoa van duoc tinh vao thong ke sau khi bo nhan.
begin;
do $$
declare
  v_email text := 'CHANGE_ME@example.com';
  v_owner uuid;
begin
  if lower(btrim(v_email))='change_me@example.com' then
    raise exception 'Hay thay v_email bang email tai khoan cua ban.';
  end if;
  select id into v_owner from auth.users where lower(email)=lower(btrim(v_email));
  if v_owner is null then raise exception 'Khong tim thay tai khoan Auth voi email nay.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text,42));

  update public.subjects
  set name=regexp_replace(name,'\s*\[MẪU\]$','')
  where owner_id=v_owner and id in (
    md5(v_owner::text||':vstudy-demo-math')::uuid,
    md5(v_owner::text||':vstudy-demo-ux')::uuid);

  update public.study_events
  set title=regexp_replace(title,'^\[MẪU\]\s*',''),
      location=replace(location,' · Dữ liệu mẫu',''),
      notes=case when notes in ('Lịch minh họa để xem giao diện, có thể sửa hoặc xóa.','Deadline minh họa.') then '' else notes end
  where owner_id=v_owner and (id=md5(v_owner::text||':vstudy-demo-deadline')::uuid
    or id in (select md5(v_owner::text||':vstudy-demo-event:'||i)::uuid from generate_series(0,6) as g(i)));

  update public.quiz_chapters
  set title=regexp_replace(title,'^\[MẪU\]\s*','')
  where owner_id=v_owner and id=md5(v_owner::text||':vstudy-demo-chapter')::uuid;

  update public.quizzes
  set title='Quiz khởi động'
  where owner_id=v_owner and chapter_id=md5(v_owner::text||':vstudy-demo-chapter')::uuid
    and title='[MẪU] Quiz khởi động';
end;
$$;
commit;
