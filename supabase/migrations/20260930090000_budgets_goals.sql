-- Velora: category budgets and savings goals.
-- Same rules as before: per-user row-level security everywhere, and inserts
-- check that referenced rows belong to the caller.

-- ---------------------------------------------------------------------------
-- Budgets: one limit per expense category, over a repeating period. Amounts
-- are in the user's main currency (minor units).
-- ---------------------------------------------------------------------------
create table public.budgets (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  category_id   uuid not null references public.categories (id) on delete cascade,
  amount_minor  bigint not null check (amount_minor > 0),
  period        text not null
                check (period in ('daily', 'weekly', 'monthly', 'yearly')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index budgets_user_category_idx
  on public.budgets (user_id, category_id);

alter table public.budgets enable row level security;

create policy "Budgets: read own" on public.budgets
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Budgets: insert own" on public.budgets
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.categories c
      where c.id = category_id and c.kind = 'expense'
    )
  );
create policy "Budgets: update own" on public.budgets
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.categories c
      where c.id = category_id and c.kind = 'expense'
    )
  );
create policy "Budgets: delete own" on public.budgets
  for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Goals: something to save for, with an optional date. Progress is the sum
-- of goal_entries: money set aside (positive) or taken back (negative).
-- ---------------------------------------------------------------------------
create table public.goals (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 32),
  target_minor   bigint not null check (target_minor > 0),
  currency_code  text not null check (currency_code ~ '^[A-Z]{3}$'),
  target_date    date,
  icon           text not null,
  color          text not null,
  created_at     timestamptz not null default now()
);

create index goals_user_idx on public.goals (user_id, created_at);

alter table public.goals enable row level security;

create policy "Goals: read own" on public.goals
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Goals: insert own" on public.goals
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Goals: update own" on public.goals
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Goals: delete own" on public.goals
  for delete to authenticated using ((select auth.uid()) = user_id);

create table public.goal_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  goal_id       uuid not null references public.goals (id) on delete cascade,
  amount_minor  bigint not null check (amount_minor <> 0),
  note          text check (note is null or char_length(note) <= 80),
  occurred_at   timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index goal_entries_goal_idx on public.goal_entries (goal_id, occurred_at);
create index goal_entries_user_idx on public.goal_entries (user_id);

alter table public.goal_entries enable row level security;

create policy "Goal entries: read own" on public.goal_entries
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Goal entries: insert own" on public.goal_entries
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.goals g where g.id = goal_id)
  );
create policy "Goal entries: delete own" on public.goal_entries
  for delete to authenticated using ((select auth.uid()) = user_id);
