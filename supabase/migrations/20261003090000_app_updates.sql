-- In-app updates for the personal build.
--
-- scripts/publish_update.py uploads each APK and a small latest.json to a
-- private "releases" bucket. The APK bundles AI keys, so it must never be
-- public: only accounts listed in release_readers can download from it.
--
-- After running this, add yourself once in the SQL editor:
--   insert into public.release_readers (user_id)
--   select id from auth.users where email = '<your backup email>';

create table if not exists public.release_readers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);

-- RLS on and no policies: the app can't read or change the list.
alter table public.release_readers enable row level security;

-- Storage policies run as the signed-in user, who can't see the table, so
-- the check runs with the owner's rights. It only answers for the caller.
create or replace function public.can_download_releases()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.release_readers r where r.user_id = auth.uid()
  );
$$;

revoke execute on function public.can_download_releases() from public, anon;
grant execute on function public.can_download_releases() to authenticated;

insert into storage.buckets (id, name, public)
values ('releases', 'releases', false)
on conflict (id) do nothing;

-- Read only. Uploads come from the publish script with the service role,
-- which bypasses these policies.
drop policy if exists "Release readers download updates" on storage.objects;
create policy "Release readers download updates"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'releases' and public.can_download_releases());
