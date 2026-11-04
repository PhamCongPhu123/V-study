-- Extend the existing private profile. Email/session remain in Supabase Auth.
alter table public.profiles
  add column class_name text not null default '' check (char_length(class_name) <= 80),
  add column major text not null default '' check (char_length(major) <= 120),
  add column birth_date date check (isfinite(birth_date) and birth_date >= date '1900-01-01' and birth_date <= current_date),
  add column avatar_key text not null default 'student' check (avatar_key in ('student','book','rocket','flower')),
  add column dark_profile boolean not null default false,
  add column study_reminders boolean not null default true;

-- Preserve profiles_select/profiles_update ownership policies and the existing
-- immutable id/created_at privileges. No new table or public storage bucket.
grant update(class_name,major,birth_date,avatar_key,dark_profile,study_reminders)
  on public.profiles to authenticated;
