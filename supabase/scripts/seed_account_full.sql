-- VSTUDY: BO DU LIEU KHOI TAO MO RONG CHO MOT TAI KHOAN.
-- Sua v_email roi chay CA FILE trong SQL Editor bang role postgres.
-- Can cac migration Vstudy den 202611040003_document_library.sql.
-- Du lieu lich su/ket qua duoc khoi tao de xem giao dien, SE TINH VAO THONG KE.
-- Khong xoa du lieu cu; ID rieng theo tai khoan giup chay lap khong tao trung.
-- Khong tao tep Storage gia; tep TXT that co trong sample_data/documents.
-- v_update_semester=true mo rong khoang thong ke hoc ky thanh 180 ngay gan nhat.
begin;
do $$
declare
  v_email text := 'CHANGE_ME@example.com'; -- SUA THANH EMAIL CUA BAN.
  v_update_semester boolean := true;
  v_owner uuid;
  v_today date := (clock_timestamp() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_banks jsonb := '[{"key": "math", "name": "Toán học", "color": "#735BF2", "questions": [{"question": "2 + 3 bằng bao nhiêu?", "options": ["5", "4", "6", "3"], "explanation": "Cộng 2 với 3 được 5."}, {"question": "Đạo hàm của x² là gì?", "options": ["2x", "x", "x²", "2"], "explanation": "Áp dụng quy tắc đạo hàm của hàm lũy thừa."}, {"question": "Tổng ba góc trong một tam giác Euclid bằng bao nhiêu?", "options": ["180°", "90°", "270°", "360°"], "explanation": "Tổng ba góc trong của tam giác Euclid bằng 180°."}, {"question": "Giá trị của 3² là bao nhiêu?", "options": ["9", "6", "8", "12"], "explanation": "3² = 3 × 3 = 9."}, {"question": "Nghiệm của 2x = 10 là gì?", "options": ["x = 5", "x = 2", "x = 10", "x = 20"], "explanation": "Chia hai vế cho 2."}, {"question": "Xác suất xuất hiện mặt ngửa khi tung một đồng xu cân đối là bao nhiêu?", "options": ["1/2", "1/3", "1/4", "1"], "explanation": "Hai kết quả ngửa và sấp có khả năng bằng nhau."}, {"question": "Trung bình cộng của 2, 4 và 6 là bao nhiêu?", "options": ["4", "3", "5", "6"], "explanation": "(2 + 4 + 6) / 3 = 4."}, {"question": "Đạo hàm của một hằng số là gì?", "options": ["0", "1", "x", "Hằng số đó"], "explanation": "Hằng số không thay đổi theo biến số."}, {"question": "Diện tích hình chữ nhật có chiều dài 5 và chiều rộng 3 là bao nhiêu?", "options": ["15", "8", "16", "30"], "explanation": "Diện tích bằng chiều dài nhân chiều rộng."}, {"question": "Một nguyên hàm của 2x là gì?", "options": ["x²", "2", "2x²", "x"], "explanation": "Đạo hàm của x² bằng 2x; nguyên hàm tổng quát thêm hằng số C."}]}, {"key": "ux", "name": "Thiết kế UX/UI", "color": "#D5AD1C", "questions": [{"question": "Wireframe chủ yếu mô tả điều gì?", "options": ["Bố cục và cấu trúc màn hình", "Database sản xuất", "Khóa API", "Mã hóa mật khẩu"], "explanation": "Wireframe giúp thống nhất cấu trúc trước khi hoàn thiện thị giác."}, {"question": "Prototype tương tác giúp kiểm tra điều gì?", "options": ["Luồng thao tác trước khi lập trình đầy đủ", "Độ bền pin thực tế", "Tốc độ máy chủ sản xuất", "Mật khẩu người dùng"], "explanation": "Prototype mô phỏng hành vi để đánh giá luồng trải nghiệm."}, {"question": "Usability testing thường được thực hiện bằng cách nào?", "options": ["Quan sát người dùng thực hiện nhiệm vụ", "Chỉ hỏi người thiết kế", "Chỉ đổi màu nền", "Bỏ mọi hướng dẫn"], "explanation": "Quan sát nhiệm vụ giúp phát hiện trở ngại thực tế."}, {"question": "Phản hồi sau thao tác giúp người dùng biết điều gì?", "options": ["Hệ thống đã tiếp nhận thao tác hay chưa", "Mật khẩu của người khác", "Cấu trúc nội bộ máy chủ", "Giá cổ phiếu"], "explanation": "Trạng thái tải, thành công và lỗi giúp người dùng hiểu kết quả thao tác."}, {"question": "Tương phản chữ và nền phù hợp hỗ trợ điều gì?", "options": ["Khả năng đọc", "Tăng kích thước database", "Tự sửa lỗi mạng", "Giảm số màn hình"], "explanation": "Tương phản là một yếu tố quan trọng của khả năng tiếp cận."}, {"question": "User flow mô tả điều gì?", "options": ["Chuỗi bước để đạt một mục tiêu", "Màu của mọi điểm ảnh", "Sơ đồ dây điện", "Dung lượng máy tính"], "explanation": "User flow tập trung vào hành trình thực hiện nhiệm vụ."}, {"question": "Thiết kế nhất quán giúp ích như thế nào?", "options": ["Giảm việc phải học lại cách thao tác", "Loại bỏ mọi lỗi dữ liệu", "Không cần thử nghiệm", "Thay thế xác thực"], "explanation": "Mẫu tương tác quen thuộc giúp người dùng dự đoán hành vi."}, {"question": "Thông báo lỗi tốt nên có đặc điểm nào?", "options": ["Nêu vấn đề và cách khắc phục phù hợp", "Chỉ hiện mã bí mật", "Đổ lỗi cho người dùng", "Ẩn toàn bộ phản hồi"], "explanation": "Thông báo rõ ràng giúp người dùng tiếp tục nhiệm vụ."}, {"question": "Persona thường được xây dựng dựa trên nguồn nào?", "options": ["Nghiên cứu về nhóm người dùng", "Sở thích riêng của lập trình viên", "Tên ngẫu nhiên", "Khóa API"], "explanation": "Persona tổng hợp nhu cầu và hành vi dựa trên nghiên cứu."}, {"question": "Khoảng trắng trong giao diện có tác dụng gì?", "options": ["Phân nhóm và tạo thứ bậc nội dung", "Luôn là diện tích bị lãng phí", "Tự tăng tốc Internet", "Thay thế nội dung"], "explanation": "Khoảng trắng giúp bố cục dễ đọc và phân biệt các nhóm."}]}, {"key": "philosophy", "name": "Triết học Mác–Lênin", "color": "#59817C", "questions": [{"question": "Theo chủ nghĩa duy vật, giữa vật chất và ý thức, yếu tố nào có trước?", "options": ["Vật chất", "Ý thức", "Cả hai đều không tồn tại", "Ý kiến cá nhân"], "explanation": "Chủ nghĩa duy vật khẳng định vật chất có trước, ý thức có sau."}, {"question": "Phép biện chứng duy vật xem xét sự vật trong trạng thái nào?", "options": ["Liên hệ, vận động và phát triển", "Hoàn toàn biệt lập", "Bất biến tuyệt đối", "Chỉ theo cảm giác cá nhân"], "explanation": "Quan điểm biện chứng xem xét quan hệ và sự biến đổi của sự vật."}, {"question": "Thực tiễn có vai trò gì đối với chân lý?", "options": ["Là tiêu chuẩn kiểm nghiệm chân lý", "Không có vai trò", "Thay thế mọi nhận thức", "Chỉ là ý tưởng"], "explanation": "Thực tiễn kiểm nghiệm tính đúng đắn của nhận thức."}, {"question": "Quan điểm toàn diện yêu cầu điều gì?", "options": ["Xem xét các mối liên hệ của sự vật", "Chỉ nhìn một mặt thuận lợi", "Bỏ qua hoàn cảnh", "Chỉ dựa trên cảm xúc"], "explanation": "Cần xem xét các mặt và các quan hệ có liên quan."}, {"question": "Quan điểm lịch sử cụ thể yêu cầu điều gì?", "options": ["Đặt sự vật trong điều kiện và hoàn cảnh xác định", "Áp dụng một kết luận cho mọi lúc", "Bỏ qua thời gian", "Chỉ ghi nhớ tên sự vật"], "explanation": "Điều kiện lịch sử cụ thể ảnh hưởng sự hình thành và phát triển."}, {"question": "Nhận thức cảm tính bao gồm hình thức nào?", "options": ["Cảm giác", "Khái niệm", "Phán đoán", "Suy luận"], "explanation": "Cảm giác, tri giác và biểu tượng thuộc nhận thức cảm tính."}, {"question": "Nhận thức lý tính bao gồm hình thức nào?", "options": ["Khái niệm", "Cảm giác", "Tri giác", "Biểu tượng"], "explanation": "Khái niệm, phán đoán và suy luận thuộc nhận thức lý tính."}, {"question": "Quy luật lượng–chất đề cập quan hệ nào?", "options": ["Tích lũy về lượng có thể dẫn đến thay đổi về chất", "Lượng và chất không liên quan", "Chỉ có lượng tồn tại", "Mọi thay đổi đều tức thời"], "explanation": "Khi đạt điều kiện thích hợp, biến đổi lượng dẫn đến biến đổi chất."}, {"question": "Trong phép biện chứng, mâu thuẫn thể hiện điều gì?", "options": ["Sự thống nhất và đấu tranh của các mặt đối lập", "Chỉ là lỗi viết sai", "Sự đồng nhất tuyệt đối", "Việc không có liên hệ"], "explanation": "Các mặt đối lập có quan hệ thống nhất và đấu tranh."}, {"question": "Ý thức có thể tác động trở lại hiện thực thông qua đâu?", "options": ["Hoạt động thực tiễn của con người", "Tự tách khỏi mọi hoạt động", "Chỉ qua giấc mơ", "Không thể có tác động"], "explanation": "Ý thức định hướng hoạt động thực tiễn của con người."}]}, {"key": "law", "name": "Pháp luật đại cương", "color": "#BD6C6C", "questions": [{"question": "Văn bản có hiệu lực pháp lý cao nhất ở Việt Nam là gì?", "options": ["Hiến pháp", "Nội quy lớp học", "Thông báo cá nhân", "Hợp đồng thuê nhà"], "explanation": "Hiến pháp có hiệu lực pháp lý cao nhất trong hệ thống pháp luật."}, {"question": "Cơ quan thực hiện quyền lập hiến và lập pháp ở Việt Nam là cơ quan nào?", "options": ["Quốc hội", "Một doanh nghiệp", "Một trường đại học", "Một câu lạc bộ"], "explanation": "Quốc hội thực hiện quyền lập hiến và lập pháp."}, {"question": "Một đặc điểm của quy phạm pháp luật là gì?", "options": ["Có tính bắt buộc chung", "Chỉ là lời khuyên cá nhân", "Không liên quan Nhà nước", "Chỉ áp dụng khi thích"], "explanation": "Quy phạm pháp luật có tính bắt buộc chung và được Nhà nước bảo đảm thực hiện."}, {"question": "Quan hệ pháp luật thường gồm những yếu tố nào?", "options": ["Chủ thể, khách thể và nội dung", "Màu sắc và kích thước", "Chỉ tên gọi", "Chỉ cảm xúc"], "explanation": "Ba yếu tố cấu thành cơ bản là chủ thể, khách thể và nội dung."}, {"question": "Hành vi nào thể hiện tuân thủ pháp luật?", "options": ["Không thực hiện hành vi bị cấm", "Luôn thực hiện hành vi bị cấm", "Bỏ qua mọi quy định", "Tự thay đổi luật"], "explanation": "Tuân thủ pháp luật là kiềm chế, không thực hiện hành vi bị cấm."}, {"question": "Thi hành pháp luật thể hiện qua hành vi nào?", "options": ["Thực hiện nghĩa vụ pháp lý", "Chỉ bàn luận về luật", "Trốn tránh nghĩa vụ", "Tự ban hành luật"], "explanation": "Thi hành pháp luật là chủ động thực hiện nghĩa vụ."}, {"question": "Sử dụng pháp luật là gì?", "options": ["Thực hiện quyền pháp luật cho phép", "Luôn thực hiện mọi điều bị cấm", "Tự xét xử người khác", "Bỏ mọi quyền"], "explanation": "Chủ thể lựa chọn thực hiện quyền được pháp luật cho phép."}, {"question": "Năng lực pháp luật dân sự của cá nhân có từ khi nào?", "options": ["Khi sinh ra", "Khi có tài khoản mạng xã hội", "Chỉ khi tốt nghiệp", "Chỉ khi có việc làm"], "explanation": "Năng lực pháp luật dân sự có từ khi sinh ra và chấm dứt khi chết."}, {"question": "Hợp đồng dân sự chủ yếu dựa trên nguyên tắc nào?", "options": ["Tự nguyện, bình đẳng và thiện chí", "Ép buộc trong mọi trường hợp", "Không cần quan tâm pháp luật", "Luôn do một bên tự quyết"], "explanation": "Các bên cần tuân thủ các nguyên tắc cơ bản của pháp luật dân sự."}, {"question": "Khi học một quy định pháp luật, điều gì cần được kiểm tra?", "options": ["Hiệu lực và văn bản hiện hành", "Chỉ tiêu đề bài đăng", "Số lượt thích", "Màu chữ"], "explanation": "Phải đối chiếu nguồn chính thức và hiệu lực của văn bản."}]}, {"key": "project", "name": "Quản trị dự án", "color": "#6B7DB6", "questions": [{"question": "Dự án thường có đặc điểm nào?", "options": ["Có mục tiêu và thời hạn xác định", "Luôn kéo dài vô hạn", "Không có nguồn lực", "Không cần kết quả"], "explanation": "Dự án là nỗ lực có thời hạn để tạo kết quả cụ thể."}, {"question": "WBS dùng để làm gì?", "options": ["Phân rã phạm vi công việc", "Lưu mật khẩu", "Nén tài liệu", "Thay thế đội dự án"], "explanation": "WBS chia công việc thành các phần dễ quản lý."}, {"question": "Stakeholder là ai?", "options": ["Bên có liên quan hoặc bị ảnh hưởng bởi dự án", "Chỉ máy chủ", "Chỉ người thiết kế logo", "Một loại tệp"], "explanation": "Các bên liên quan có lợi ích hoặc ảnh hưởng tới dự án."}, {"question": "Critical path thường chỉ điều gì?", "options": ["Chuỗi công việc quyết định thời gian hoàn thành dự án", "Đường đi ngắn nhất tới trường", "Danh sách màu sắc", "Một bản sao dữ liệu"], "explanation": "Chậm trễ trên đường găng có thể làm chậm ngày hoàn thành."}, {"question": "Quản lý rủi ro bắt đầu bằng bước nào?", "options": ["Nhận diện rủi ro", "Bỏ qua mọi vấn đề", "Chi toàn bộ ngân sách", "Hủy mọi kế hoạch"], "explanation": "Cần nhận diện trước khi phân tích và chọn cách ứng phó."}, {"question": "Milestone là gì?", "options": ["Mốc quan trọng của dự án", "Mật khẩu dự án", "Một người bất kỳ", "Tệp video"], "explanation": "Milestone đánh dấu một sự kiện hay kết quả quan trọng."}, {"question": "Scope creep mô tả tình huống nào?", "options": ["Phạm vi tăng không được kiểm soát", "Phạm vi được quản lý rõ ràng", "Ngân sách không có giới hạn", "Mọi công việc đều hoàn tất"], "explanation": "Thay đổi phạm vi không kiểm soát gây ảnh hưởng tiến độ và nguồn lực."}, {"question": "Kanban thường dùng để làm gì?", "options": ["Trực quan hóa trạng thái công việc", "Lưu dữ liệu mật khẩu", "Đổi cấu trúc máy tính", "Xóa mọi công việc"], "explanation": "Bảng Kanban giúp theo dõi luồng công việc."}, {"question": "Retrospective trong nhóm giúp làm gì?", "options": ["Nhìn lại và cải tiến cách làm việc", "Chỉ phân công lỗi cho cá nhân", "Thay thế mọi kiểm thử", "Bỏ kế hoạch tiếp theo"], "explanation": "Nhóm học từ trải nghiệm để điều chỉnh cách phối hợp."}, {"question": "Kế hoạch truyền thông xác định điều gì?", "options": ["Ai cần thông tin gì, khi nào và qua kênh nào", "Chỉ màu sắc slide", "Mật khẩu cá nhân", "Loại bàn làm việc"], "explanation": "Truyền thông phù hợp giúp các bên liên quan phối hợp hiệu quả."}]}]'::jsonb;
  v_subjects uuid[] := '{}';
  v_keys text[] := array['math','ux','philosophy','law','project'];
  v_titles text[] := array['Kiến thức nền tảng','Vận dụng và ôn tập','Tự kiểm tra tổng hợp'];
  v_thread_titles text[] := array['Cách ôn tập hiệu quả','Kế hoạch học trong tuần','Ôn tập bằng flashcard'];
  v_modes text[] := array['qa','plan','flashcards'];
  v_questions text[] := array['Làm sao ghi nhớ kiến thức tốt hơn?','Gợi ý cách sắp xếp lịch học một tuần.','Cho mình vài thẻ ghi nhớ về cách học.'];
  v_replies text[] := array[
    'Chia nội dung thành phần nhỏ, tự nhớ lại mà không nhìn tài liệu, rồi ôn lại sau các khoảng thời gian tăng dần. Dùng Quiz để tìm phần cần ôn.',
    'Chọn mục tiêu tuần, chia thành các buổi học cụ thể, dành thời gian cho bài khó và chừa khoảng nghỉ. Điều chỉnh theo lịch trên lớp thực tế.',
    'Hỏi: Active recall là gì? Đáp: Tự nhớ lại kiến thức khi chưa xem đáp án. Hỏi: Spaced repetition là gì? Đáp: Ôn lại kiến thức theo các khoảng thời gian giãn cách.'
  ];
  v_subject uuid; v_chapter uuid; v_quiz uuid; v_question uuid; v_event uuid;
  v_attempt uuid; v_thread uuid; v_bank jsonb; v_item jsonb; v_options jsonb;
  v_answers jsonb; v_time timestamptz; v_old_claim text;
  s integer; c integer; b integer; q integer; i integer; j integer; n integer;
  v_rotation integer; v_set integer := 0;
begin
  if lower(btrim(v_email))='change_me@example.com' then raise exception 'Hay sua v_email thanh email da dang ky.'; end if;
  select id into v_owner from auth.users where lower(email)=lower(btrim(v_email));
  if v_owner is null then raise exception 'Email chua co trong Authentication -> Users.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text,42));
  insert into public.profiles(id,display_name)
    select id,left(coalesce(nullif(btrim(raw_user_meta_data->>'display_name'),''),'Bạn học'),100)
    from auth.users where id=v_owner on conflict(id) do nothing;
  v_old_claim := current_setting('request.jwt.claim.sub',true);
  perform set_config('request.jwt.claim.sub',v_owner::text,true);

  for s in 0..4 loop
    v_bank := v_banks->s;
    v_subject := md5(v_owner::text||':vstudy-demo-'||v_keys[s+1])::uuid;
    v_subjects := array_append(v_subjects,v_subject);
    insert into public.subjects(id,owner_id,name,color)
      values(v_subject,v_owner,v_bank->>'name',v_bank->>'color') on conflict(id) do nothing;
    for c in 0..2 loop
      v_chapter := case when s=0 and c=0 then md5(v_owner::text||':vstudy-demo-chapter')::uuid
        else md5(v_owner::text||':vstudy-expanded-chapter:'||s||':'||c)::uuid end;
      insert into public.quiz_chapters(id,owner_id,subject_id,title,position)
        values(v_chapter,v_owner,v_subject,'Chương '||(c+1)||' · '||v_titles[c+1],c)
        on conflict(id) do nothing;
      for b in 0..1 loop
        v_set := v_set+1;
        v_quiz := md5(v_owner::text||':vstudy-expanded-quiz:'||s||':'||c||':'||b)::uuid;
        insert into public.quizzes(id,owner_id,subject_id,chapter_id,title,topic,duration_minutes,difficulty,created_at)
          values(v_quiz,v_owner,v_subject,v_chapter,
            'Chương '||(c+1)||' · Bộ đề '||(b+1),
            'Ôn tập khởi tạo · '||(v_bank->>'name'),15+b*5,case when b=0 then 'easy' else 'medium' end,
            clock_timestamp()-make_interval(days=>v_set%20)) on conflict(id) do nothing;
        for q in 0..4 loop
          v_item := v_bank->'questions'->((c*3+b*5+q)%10);
          v_rotation := (s+c+b+q)%4;
          select jsonb_agg((v_item->'options')->((x+v_rotation)%4) order by x)
            into v_options from generate_series(0,3) as g(x);
          v_question := md5(v_quiz::text||':question:'||q)::uuid;
          insert into public.quiz_questions(id,quiz_id,owner_id,position,question,options,hint)
            values(v_question,v_quiz,v_owner,q,v_item->>'question',v_options,
              'Ôn lại khái niệm trước khi chọn đáp án.') on conflict(id) do nothing;
          insert into public.quiz_answer_keys(question_id,quiz_id,correct_option,explanation)
            values(v_question,v_quiz,(4-v_rotation)%4,v_item->>'explanation') on conflict(question_id) do nothing;
        end loop;
        -- Ket qua minh hoa: cham bang RPC that, khong gan diem tuy y.
        for n in 1..2 loop
          v_attempt := md5(v_quiz::text||':initial-attempt:'||n)::uuid;
          if not exists(select 1 from public.quiz_attempts where id=v_attempt) then
            select jsonb_object_agg(qq.id::text,
              case when (qq.position+v_set+n)%(case when n=1 then 3 else 5 end)=0
                then (k.correct_option+1)%4 else k.correct_option end)
              into v_answers from public.quiz_questions qq join public.quiz_answer_keys k on k.question_id=qq.id
              where qq.quiz_id=v_quiz;
            perform public.submit_quiz_attempt(v_quiz,v_answers,v_attempt,false,
              case when n=1 then 'practice' else 'exam' end);
            update public.quiz_attempts set submitted_at=
              ((v_today-((v_set*3+n*5)%60+1))::timestamp+interval '20 hours') at time zone 'Asia/Ho_Chi_Minh'
              where id=v_attempt and owner_id=v_owner;
          end if;
        end loop;
      end loop;
    end loop;
  end loop;
  perform set_config('request.jwt.claim.sub',coalesce(v_old_claim,''),true);

  -- 8 tuan: 2 buoi hoc/ngay thu 2-6, tu hoc thu 2/4/6, deadline thu 6.
  for i in -14..41 loop
    v_subject := v_subjects[1+((i+14)%5)];
    if extract(isodow from v_today+i) between 1 and 5 then
      for j in 0..1 loop
        v_event := md5(v_owner::text||':vstudy-expanded-event:'||i||':'||j)::uuid;
        v_time := ((v_today+i)::timestamp+make_interval(hours=>10+j*4)) at time zone 'Asia/Ho_Chi_Minh';
        insert into public.study_events(id,owner_id,subject_id,title,kind,starts_at,ends_at,location,notes,reminder_minutes)
          values(v_event,v_owner,v_subject,case when j=0 then 'Học trên lớp · ' else 'Ôn tập · ' end||
            (select name from public.subjects where id=v_subject),
            case when j=0 then 'class' else 'self_study' end,v_time,v_time+interval '90 minutes',
            case when j=0 then 'Phòng A101' else 'Thư viện' end,
            'Nội dung khởi tạo để thử luồng học tập.',30) on conflict(id) do nothing;
        for n in 1..2 loop
          insert into public.event_tasks(id,event_id,owner_id,title,is_completed)
            values(md5(v_event::text||':task:'||n)::uuid,v_event,v_owner,
              case when n=1 then 'Đọc tài liệu trước buổi học' else 'Tự kiểm tra kiến thức' end,
              i<0) on conflict(id) do nothing;
        end loop;
      end loop;
    end if;
    if extract(isodow from v_today+i) in (1,3,5) then
      v_time := ((v_today+i)::timestamp+interval '19 hours') at time zone 'Asia/Ho_Chi_Minh';
      insert into public.study_events(id,owner_id,subject_id,title,kind,starts_at,ends_at,notes)
        values(md5(v_owner::text||':vstudy-expanded-evening:'||i)::uuid,v_owner,v_subject,
          'Ôn Quiz và flashcard','self_study',v_time,v_time+interval '1 hour','Buổi ôn tập khởi tạo.')
        on conflict(id) do nothing;
    end if;
    if extract(isodow from v_today+i)=5 then
      v_time := ((v_today+i)::timestamp+interval '17 hours') at time zone 'Asia/Ho_Chi_Minh';
      insert into public.study_events(id,owner_id,subject_id,title,kind,starts_at,ends_at,notes)
        values(md5(v_owner::text||':vstudy-expanded-deadline:'||i)::uuid,v_owner,v_subject,
          'Nộp bài tập tuần','deadline',v_time,v_time+interval '1 hour','Deadline khởi tạo.')
        on conflict(id) do nothing;
    end if;
  end loop;

  -- 180 ngay lich su de xem bieu do tuan/thang/hoc ky.
  for i in 1..180 loop
    v_subject := v_subjects[1+(i%5)];
    if i%7<>0 then
      insert into public.study_sessions(id,owner_id,subject_id,started_at,duration_minutes)
        values(md5(v_owner::text||':vstudy-expanded-study:'||i)::uuid,v_owner,v_subject,
          ((v_today-i)::timestamp+interval '18 hours') at time zone 'Asia/Ho_Chi_Minh',45+(i%6)*15)
        on conflict(id) do nothing;
      insert into public.flashcard_sessions(id,owner_id,subject_id,reviewed_at,reviewed_cards,remembered_cards)
        values(md5(v_owner::text||':vstudy-expanded-flash:'||i)::uuid,v_owner,v_subject,
          ((v_today-i)::timestamp+interval '19 hours') at time zone 'Asia/Ho_Chi_Minh',20+(i%4)*5,15+(i%4)*5)
        on conflict(id) do nothing;
    end if;
    if i%2=0 then
      insert into public.focus_sessions(id,owner_id,subject_id,started_at,planned_minutes,focused_minutes,interruptions)
        values(md5(v_owner::text||':vstudy-expanded-focus:'||i)::uuid,v_owner,v_subject,
          ((v_today-i)::timestamp+interval '16 hours') at time zone 'Asia/Ho_Chi_Minh',50,30+(i%5)*4,i%3)
        on conflict(id) do nothing;
    end if;
  end loop;
  -- Hoat dong gan hien tai de Trang chu co tien do ngay dau tien.
  insert into public.study_sessions(id,owner_id,subject_id,started_at,duration_minutes)
    values(md5(v_owner::text||':vstudy-expanded-current-study')::uuid,v_owner,v_subjects[1],
      clock_timestamp()-interval '75 minutes',60) on conflict(id) do nothing;
  insert into public.focus_sessions(id,owner_id,subject_id,started_at,planned_minutes,focused_minutes,interruptions)
    values(md5(v_owner::text||':vstudy-expanded-current-focus')::uuid,v_owner,v_subjects[1],
      clock_timestamp()-interval '45 minutes',25,20,1) on conflict(id) do nothing;
  insert into public.flashcard_sessions(id,owner_id,subject_id,reviewed_at,reviewed_cards,remembered_cards)
    values(md5(v_owner::text||':vstudy-expanded-current-flash')::uuid,v_owner,v_subjects[1],
      clock_timestamp()-interval '10 minutes',20,16) on conflict(id) do nothing;

  insert into public.study_goals(owner_id,weekly_minutes,study_days_per_week,flashcards_per_day,semester_start,semester_end)
    values(v_owner,900,5,20,v_today-179,v_today+1) on conflict(owner_id) do nothing;
  if v_update_semester then
    update public.study_goals set semester_start=v_today-179,semester_end=v_today+1 where owner_id=v_owner;
  end if;

  for i in 1..3 loop
    v_thread := md5(v_owner::text||':vstudy-expanded-thread:'||i)::uuid;
    insert into public.chat_threads(id,owner_id,title,mode,updated_at)
      values(v_thread,v_owner,v_thread_titles[i],v_modes[i],clock_timestamp()-make_interval(hours=>i))
      on conflict(id) do nothing;
    insert into public.chat_messages(id,thread_id,owner_id,role,content,created_at) values
      (md5(v_thread::text||':user')::uuid,v_thread,v_owner,'user',v_questions[i],clock_timestamp()-make_interval(hours=>i,mins=>1)),
      (md5(v_thread::text||':assistant')::uuid,v_thread,v_owner,'assistant',
       'Cuộc hội thoại này được khởi tạo sẵn để tham khảo, chưa gọi dịch vụ AI.'||chr(10)||chr(10)||v_replies[i],
       clock_timestamp()-make_interval(hours=>i))
      on conflict(id) do nothing;
  end loop;
  -- Bo cac nhan cu cua bo khoi tao nho, giu nguyen ten da tu chinh sua.
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
    or id in (select md5(v_owner::text||':vstudy-demo-event:'||g.i)::uuid from generate_series(0,6) as g(i)));

  update public.quiz_chapters
  set title=regexp_replace(title,'^\[MẪU\]\s*','')
  where owner_id=v_owner and id=md5(v_owner::text||':vstudy-demo-chapter')::uuid;

  update public.quizzes
  set title='Quiz khởi động'
  where owner_id=v_owner and chapter_id=md5(v_owner::text||':vstudy-demo-chapter')::uuid
    and title='[MẪU] Quiz khởi động';

  raise notice 'Da them bo du lieu khoi tao mo rong. Tai lai cac tab hoac dang nhap lai de xem.';
end;
$$;
commit;
