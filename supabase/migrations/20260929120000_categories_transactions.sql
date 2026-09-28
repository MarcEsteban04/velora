-- Velora: categories, transactions and live account balances.
-- As before, every table has per-user row-level security. Inserts also check
-- that referenced accounts and categories belong to the caller.

-- ---------------------------------------------------------------------------
-- Categories (expense or income). The icon and color are keys the app maps
-- to its design tokens, so the palette can change without a migration.
-- ---------------------------------------------------------------------------
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
              references auth.users (id) on delete cascade,
  kind        text not null check (kind in ('expense', 'income')),
  name        text not null check (char_length(btrim(name)) between 1 and 24),
  icon        text not null,
  color       text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);

create unique index categories_user_kind_name_idx
  on public.categories (user_id, kind, lower(name));

alter table public.categories enable row level security;

create policy "Categories: read own" on public.categories
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Categories: insert own" on public.categories
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Categories: update own" on public.categories
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Categories: delete own" on public.categories
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Seeds the starter categories once per user. Safe to call repeatedly.
create or replace function public.ensure_default_categories()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if exists (select 1 from public.categories where user_id = auth.uid()) then
    return;
  end if;
  insert into public.categories (kind, name, icon, color, sort_order) values
    ('expense', 'Food',          'food',      'ember',  0),
    ('expense', 'Transport',     'transport', 'sky',    1),
    ('expense', 'Groceries',     'groceries', 'leaf',   2),
    ('expense', 'Bills',         'bills',     'amber',  3),
    ('expense', 'Shopping',      'shopping',  'rose',   4),
    ('expense', 'Fun',           'fun',       'lilac',  5),
    ('expense', 'Health',        'health',    'coral',  6),
    ('expense', 'Phone & net',   'phone',     'teal',   7),
    ('expense', 'Home',          'home',      'rust',   8),
    ('expense', 'Other',         'other',     'slate',  9),
    ('income',  'Salary',        'salary',    'leaf',   0),
    ('income',  'Freelance',     'freelance', 'sky',    1),
    ('income',  'Gift',          'gift',      'rose',   2),
    ('income',  'Refund',        'refund',    'teal',   3),
    ('income',  'Interest',      'interest',  'amber',  4),
    ('income',  'Other',         'other',     'slate',  5);
end;
$$;

revoke execute on function public.ensure_default_categories() from public, anon;
grant execute on function public.ensure_default_categories() to authenticated;

-- ---------------------------------------------------------------------------
-- Transactions. Amounts are always positive minor units; `kind` gives the
-- direction. A transfer moves money from account_id to to_account_id.
-- to_amount_minor is only set when the two accounts use different
-- currencies.
-- ---------------------------------------------------------------------------
create table public.transactions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  kind             text not null check (kind in ('expense', 'income', 'transfer')),
  amount_minor     bigint not null check (amount_minor > 0),
  account_id       uuid not null references public.accounts (id) on delete cascade,
  to_account_id    uuid references public.accounts (id) on delete cascade,
  to_amount_minor  bigint check (to_amount_minor is null or to_amount_minor > 0),
  category_id      uuid references public.categories (id) on delete set null,
  note             text check (note is null or char_length(note) <= 140),
  occurred_at      timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  constraint transfer_shape check (
    (kind = 'transfer' and to_account_id is not null and to_account_id <> account_id
       and category_id is null)
    or (kind <> 'transfer' and to_account_id is null and to_amount_minor is null)
  )
);

create index transactions_user_occurred_idx
  on public.transactions (user_id, occurred_at desc);
create index transactions_account_idx on public.transactions (account_id);
create index transactions_to_account_idx on public.transactions (to_account_id)
  where to_account_id is not null;

alter table public.transactions enable row level security;

-- Referenced rows must also be the caller's. The subqueries run under the
-- caller's own RLS, so other users' ids simply don't exist to them.
create policy "Transactions: read own" on public.transactions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Transactions: insert own" on public.transactions
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.accounts a where a.id = account_id)
    and (to_account_id is null
         or exists (select 1 from public.accounts a where a.id = to_account_id))
    and (category_id is null
         or exists (select 1 from public.categories c where c.id = category_id))
  );
create policy "Transactions: update own" on public.transactions
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.accounts a where a.id = account_id)
    and (to_account_id is null
         or exists (select 1 from public.accounts a where a.id = to_account_id))
    and (category_id is null
         or exists (select 1 from public.categories c where c.id = category_id))
  );
create policy "Transactions: delete own" on public.transactions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Live balances: opening balance plus everything that has happened since.
-- security_invoker makes the view obey the caller's RLS.
-- ---------------------------------------------------------------------------
create or replace view public.account_balances
with (security_invoker = true) as
select
  a.id as account_id,
  a.opening_balance_minor + coalesce(sum(
    case
      when t.kind = 'income'   and t.account_id    = a.id then  t.amount_minor
      when t.kind = 'expense'  and t.account_id    = a.id then -t.amount_minor
      when t.kind = 'transfer' and t.account_id    = a.id then -t.amount_minor
      when t.kind = 'transfer' and t.to_account_id = a.id
        then coalesce(t.to_amount_minor, t.amount_minor)
      else 0
    end
  ), 0)::bigint as balance_minor
from public.accounts a
left join public.transactions t
  on t.account_id = a.id or t.to_account_id = a.id
group by a.id, a.opening_balance_minor;

grant select on public.account_balances to authenticated;
