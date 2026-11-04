-- Organize private documents without changing their Storage ownership.
begin;
alter table public.documents
  add column subject_id uuid,
  add column is_favorite boolean not null default false,
  add constraint documents_subject_owner_fk foreign key(subject_id,owner_id)
    references public.subjects(id,owner_id) on delete set null (subject_id);
create index documents_library_idx on public.documents(owner_id,subject_id,is_favorite);
-- Metadata and object paths remain immutable after upload.
revoke update on public.documents from public,anon,authenticated;
grant update(subject_id,is_favorite) on public.documents to authenticated;
commit;
