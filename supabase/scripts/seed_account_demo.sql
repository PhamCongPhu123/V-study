-- DU LIEU MINH HOA cho mot tai khoan Auth da ton tai.
-- Sua v_email, dan CA FILE vao Supabase SQL Editor va Run bang role postgres.
-- Can cac migration Vstudy (schema, quiz, statistics). Khong tao tai khoan/mat khau.
-- Co the chay lai: ID mau rieng theo tai khoan, khong ghi de du lieu da co.
-- Lich su hoc mau SE DUOC TINH VAO THONG KE; cac mon/lich/quiz duoc gan nhan MAU.
-- Khong tao tep Storage, lich su chat AI hoac diem quiz gia.
begin;
do $$
declare
  v_email text := 'CHANGE_ME@example.com'; -- THAY BANG EMAIL TAI KHOAN MOI.
  v_owner uuid;
  v_math uuid;
  v_ux uuid;
  v_chapter uuid;
  v_today date := (clock_timestamp() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_subject uuid;
  i integer;
begin
  if lower(btrim(v_email))='change_me@example.com' then
    raise exception 'Hay thay v_email bang email tai khoan cua ban trong Authentication -> Users.';
  end if;
  select id into v_owner from auth.users where lower(email)=lower(btrim(v_email));
  if v_owner is null then raise exception 'Email chua co trong Authentication -> Users.'; end if;
  -- Serialize repeated clicks for this same account.
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text, 42));
  v_math := md5(v_owner::text || ':vstudy-demo-math')::uuid;
  v_ux := md5(v_owner::text || ':vstudy-demo-ux')::uuid;
  v_chapter := md5(v_owner::text || ':vstudy-demo-chapter')::uuid;

  insert into public.profiles(id,display_name)
  select id,left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),
    nullif(btrim(raw_user_meta_data->>'full_name'),''),'Bạn học'),100)
  from auth.users where id=v_owner on conflict(id) do nothing;

  insert into public.subjects(id,owner_id,name,color) values
    (v_math,v_owner,'Toán học [MẪU]','#735BF2'),
    (v_ux,v_owner,'Thiết kế UX/UI [MẪU]','#D5AD1C')
  on conflict(id) do nothing;

  for i in 0..6 loop
    v_subject := case when i%2=0 then v_math else v_ux end;
    insert into public.study_events(id,owner_id,subject_id,title,kind,starts_at,ends_at,location,notes)
    values(md5(v_owner::text||':vstudy-demo-event:'||i)::uuid,v_owner,v_subject,
      case when i%2=0 then '[MẪU] Học Toán' else '[MẪU] Ôn thiết kế giao diện' end,
      case when i%2=0 then 'class' else 'self_study' end,
      ((v_today+i)::timestamp+interval '8 hours') at time zone 'Asia/Ho_Chi_Minh',
      ((v_today+i)::timestamp+interval '10 hours') at time zone 'Asia/Ho_Chi_Minh',
      'Phòng A101 · Dữ liệu mẫu','Lịch minh họa để xem giao diện, có thể sửa hoặc xóa.')
    on conflict(id) do nothing;
  end loop;
  insert into public.study_events(id,owner_id,subject_id,title,kind,starts_at,ends_at,notes)
  values(md5(v_owner::text||':vstudy-demo-deadline')::uuid,v_owner,v_ux,'[MẪU] Nộp bài UX/UI','deadline',
    ((v_today+1)::timestamp+interval '20 hours') at time zone 'Asia/Ho_Chi_Minh',
    ((v_today+1)::timestamp+interval '21 hours') at time zone 'Asia/Ho_Chi_Minh','Deadline minh họa.')
  on conflict(id) do nothing;

  for i in 1..7 loop
    insert into public.study_sessions(id,owner_id,subject_id,started_at,duration_minutes)
    values(md5(v_owner::text||':vstudy-demo-study:'||i)::uuid,v_owner,
      case when i%2=0 then v_math else v_ux end,
      ((v_today-i)::timestamp+interval '18 hours') at time zone 'Asia/Ho_Chi_Minh',60+i*10)
    on conflict(id) do nothing;
  end loop;
  for i in 1..3 loop
    insert into public.focus_sessions(id,owner_id,subject_id,started_at,planned_minutes,focused_minutes,interruptions)
    values(md5(v_owner::text||':vstudy-demo-focus:'||i)::uuid,v_owner,v_math,
      ((v_today-i)::timestamp+interval '10 hours') at time zone 'Asia/Ho_Chi_Minh',50,35,2)
    on conflict(id) do nothing;
    insert into public.flashcard_sessions(id,owner_id,subject_id,reviewed_at,reviewed_cards,remembered_cards)
    values(md5(v_owner::text||':vstudy-demo-flashcard:'||i)::uuid,v_owner,v_math,
      ((v_today-i)::timestamp+interval '19 hours') at time zone 'Asia/Ho_Chi_Minh',20,15)
    on conflict(id) do nothing;
  end loop;

  insert into public.study_goals(owner_id,weekly_minutes,study_days_per_week,flashcards_per_day,semester_start,semester_end)
  values(v_owner,900,5,20,v_today-30,v_today+120) on conflict(owner_id) do nothing;
  insert into public.quiz_chapters(id,owner_id,subject_id,title,position)
  values(v_chapter,v_owner,v_math,'[MẪU] Kiến thức cơ bản',0) on conflict(id) do nothing;
  if not exists(select 1 from public.quizzes where owner_id=v_owner and chapter_id=v_chapter) then
    perform public.create_generated_quiz(v_owner,'[MẪU] Quiz khởi động','Toán học cơ bản',null,
      '[
        {"question":"2 + 3 bằng bao nhiêu?","options":["5","4","6","3"],"correct_option":0,"explanation":"Cộng 2 với 3 được 5."},
        {"question":"Đạo hàm của x² là gì?","options":["2x","x","x²","2"],"correct_option":0,"explanation":"Theo quy tắc lũy thừa: (xⁿ)′ = n·xⁿ⁻¹."},
        {"question":"Một tam giác có tổng ba góc trong bằng bao nhiêu?","options":["180°","90°","270°","360°"],"correct_option":0,"explanation":"Trong hình học Euclid, tổng ba góc trong của tam giác bằng 180°."}
      ]'::jsonb,v_math,v_chapter,15,'easy');
  end if;
  raise notice 'Da them du lieu MAU cho dung tai khoan. Dang nhap lai hoac tai lai cac tab de xem.';
end;
$$;
commit;
