-- Debts: what the user owes (a credit card, a pay-later plan, a loan,
-- money borrowed from someone). What's left comes from debt_entries:
-- payments (positive) and borrowing more (negative), like goals.

create table if not exists public.debts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  name           text not null check (char_length(btrim(name)) between 1 and 32),
  kind           text not null default 'loan'
                 check (kind in ('card', 'bnpl', 'loan', 'personal')),
  currency_code  text not null check (currency_code ~ '^[A-Z]{3}$'),
  -- What was owed when it was added.
  owed_minor     bigint not null check (owed_minor > 0),
  -- The usual payment, and the day of the month it's due, if any.
  monthly_minor  bigint check (monthly_minor is null or monthly_minor > 0),
  due_day        smallint check (due_day is null or due_day between 1 and 31),
  created_at     timestamptz not null default now()
);

create index if not exists debts_user_idx on public.debts (user_id, created_at);

alter table public.debts enable row level security;

drop policy if exists "Debts: read own" on public.debts;
drop policy if exists "Debts: insert own" on public.debts;
drop policy if exists "Debts: update own" on public.debts;
drop policy if exists "Debts: delete own" on public.debts;
create policy "Debts: read own" on public.debts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Debts: insert own" on public.debts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Debts: update own" on public.debts
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Debts: delete own" on public.debts
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.debt_entries (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  debt_id         uuid not null references public.debts (id) on delete cascade,
  -- Paid down (positive) or borrowed more (negative), in the debt's currency.
  amount_minor    bigint not null check (amount_minor <> 0),
  note            text check (note is null or char_length(note) <= 80),
  occurred_at     timestamptz not null default now(),
  -- The expense that paid it, when the money came out of an account.
  transaction_id  uuid references public.transactions (id) on delete set null,
  created_at      timestamptz not null default now()
);

create index if not exists debt_entries_debt_idx
  on public.debt_entries (debt_id, occurred_at desc);

alter table public.debt_entries enable row level security;

drop policy if exists "Debt entries: read own" on public.debt_entries;
drop policy if exists "Debt entries: insert own" on public.debt_entries;
drop policy if exists "Debt entries: delete own" on public.debt_entries;
create policy "Debt entries: read own" on public.debt_entries
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Debt entries: insert own" on public.debt_entries
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.debts d
      where d.id = debt_id and d.user_id = (select auth.uid())
    )
  );
create policy "Debt entries: delete own" on public.debt_entries
  for delete to authenticated using ((select auth.uid()) = user_id);

-- A payment toward a debt, in one step: the entry, and when it came out
-- of an account, the expense too. Runs as the caller, so row-level
-- security applies to both tables. Returns the entry's id.
create or replace function public.record_debt_payment(
  p_debt uuid,
  p_amount_minor bigint,
  p_paid_at timestamptz,
  p_account uuid,
  p_category uuid,
  p_note text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text;
  v_tx uuid;
  v_entry uuid;
begin
  if p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'A payment must be more than zero' using errcode = '22023';
  end if;
  select name into v_name from public.debts where id = p_debt;
  if v_name is null then
    raise exception 'Debt not found' using errcode = 'P0002';
  end if;

  if p_account is not null then
    insert into public.transactions
      (kind, amount_minor, account_id, category_id, note, occurred_at)
    values
      ('expense', p_amount_minor, p_account, p_category,
       coalesce(nullif(btrim(p_note), ''), v_name || ' payment'), p_paid_at)
    returning id into v_tx;
  end if;

  insert into public.debt_entries
    (debt_id, amount_minor, note, occurred_at, transaction_id)
  values
    (p_debt, p_amount_minor, nullif(btrim(p_note), ''), p_paid_at, v_tx)
  returning id into v_entry;

  return v_entry;
end;
$$;

revoke execute on function public.record_debt_payment(uuid, bigint, timestamptz, uuid, uuid, text)
  from public, anon;
grant execute on function public.record_debt_payment(uuid, bigint, timestamptz, uuid, uuid, text)
  to authenticated;
