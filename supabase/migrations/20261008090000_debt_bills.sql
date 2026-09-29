-- Bills on a credit line: a pay-later plan or card owes several monthly
-- bills at once (SPayLater's "My Bill": Oct due Nov 15, Nov due Dec 15...).
-- A payment can go to one of them; what a bill still needs comes from the
-- payments that name it.

create table if not exists public.debt_bills (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  debt_id       uuid not null references public.debts (id) on delete cascade,
  -- What the bill asks for, in the debt's currency, and when it's due.
  amount_minor  bigint not null check (amount_minor > 0),
  due_on        date not null,
  created_at    timestamptz not null default now(),
  -- One bill per due date: scanning the list again updates it.
  unique (debt_id, due_on)
);

create index if not exists debt_bills_debt_idx
  on public.debt_bills (debt_id, due_on);

alter table public.debt_bills enable row level security;

drop policy if exists "Debt bills: read own" on public.debt_bills;
drop policy if exists "Debt bills: insert own" on public.debt_bills;
drop policy if exists "Debt bills: update own" on public.debt_bills;
drop policy if exists "Debt bills: delete own" on public.debt_bills;
create policy "Debt bills: read own" on public.debt_bills
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Debt bills: insert own" on public.debt_bills
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.debts d
      where d.id = debt_id and d.user_id = (select auth.uid())
    )
  );
create policy "Debt bills: update own" on public.debt_bills
  for update to authenticated
  using ((select auth.uid()) = user_id) with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.debts d
      where d.id = debt_id and d.user_id = (select auth.uid())
    )
  );
create policy "Debt bills: delete own" on public.debt_bills
  for delete to authenticated using ((select auth.uid()) = user_id);

-- The bill a payment went to. Deleting the bill keeps the payment.
alter table public.debt_entries
  add column if not exists bill_id uuid
    references public.debt_bills (id) on delete set null;

-- record_debt_payment gains the bill it pays.
drop function if exists public.record_debt_payment(uuid, bigint, timestamptz, uuid, uuid, text);

create or replace function public.record_debt_payment(
  p_debt uuid,
  p_amount_minor bigint,
  p_paid_at timestamptz,
  p_account uuid,
  p_category uuid,
  p_note text,
  p_bill uuid default null
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
  if p_bill is not null and not exists (
    select 1 from public.debt_bills b where b.id = p_bill and b.debt_id = p_debt
  ) then
    raise exception 'Bill not found' using errcode = 'P0002';
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
    (debt_id, amount_minor, note, occurred_at, transaction_id, bill_id)
  values
    (p_debt, p_amount_minor, nullif(btrim(p_note), ''), p_paid_at, v_tx, p_bill)
  returning id into v_entry;

  return v_entry;
end;
$$;

revoke execute on function public.record_debt_payment(uuid, bigint, timestamptz, uuid, uuid, text, uuid)
  from public, anon;
grant execute on function public.record_debt_payment(uuid, bigint, timestamptz, uuid, uuid, text, uuid)
  to authenticated;
