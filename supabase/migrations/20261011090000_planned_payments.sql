-- Planned payments: bills and subscriptions that come round again (rent,
-- electricity, internet, Netflix), and expected income (salary). Paying
-- one logs the transaction and moves it to its next date, in one step.

create table if not exists public.planned_payments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  kind          text not null default 'expense'
                check (kind in ('expense', 'income')),
  name          text not null check (char_length(btrim(name)) between 1 and 40),
  amount_minor  bigint not null check (amount_minor > 0),
  account_id    uuid not null references public.accounts (id) on delete cascade,
  category_id   uuid references public.categories (id) on delete set null,
  -- How it repeats: once, or every N weeks, months or years.
  repeat        text not null default 'monthly'
                check (repeat in ('once', 'weekly', 'monthly', 'yearly')),
  every         smallint not null default 1 check (every between 1 and 12),
  -- The day of the month it falls on (monthly and yearly), kept even when
  -- a short month moves one date earlier: due the 31st stays the 31st.
  anchor_day    smallint check (anchor_day is null or anchor_day between 1 and 31),
  next_due      date not null,
  -- Days before the due date to remind; null for no reminder.
  remind_days   smallint check (remind_days is null or remind_days between 0 and 7),
  -- Log it automatically on its date (fixed subscriptions).
  auto_log      boolean not null default false,
  -- Set when a one-off is paid, or a repeating one is stopped.
  done_at       timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists planned_payments_user_due_idx
  on public.planned_payments (user_id, next_due);

alter table public.planned_payments enable row level security;

drop policy if exists "Planned: read own" on public.planned_payments;
drop policy if exists "Planned: insert own" on public.planned_payments;
drop policy if exists "Planned: update own" on public.planned_payments;
drop policy if exists "Planned: delete own" on public.planned_payments;
create policy "Planned: read own" on public.planned_payments
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Planned: insert own" on public.planned_payments
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.accounts a
      where a.id = account_id and a.user_id = (select auth.uid())
    )
  );
create policy "Planned: update own" on public.planned_payments
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Planned: delete own" on public.planned_payments
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Which planned payment a transaction paid, for its history.
alter table public.transactions
  add column if not exists planned_id uuid
    references public.planned_payments (id) on delete set null;

create index if not exists transactions_planned_idx
  on public.transactions (planned_id) where planned_id is not null;

-- Pays one: logs the transaction and moves it on to p_next_due, or marks
-- it done when there's no next date. Runs as the caller, so row-level
-- security applies. Returns the transaction's id.
create or replace function public.pay_planned_payment(
  p_planned uuid,
  p_amount_minor bigint,
  p_paid_at timestamptz,
  p_account uuid,
  p_next_due date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v public.planned_payments%rowtype;
  v_tx uuid;
begin
  select * into v from public.planned_payments
  where id = p_planned and done_at is null
  for update;
  if v.id is null then
    raise exception 'Planned payment not found or already done'
      using errcode = 'P0002';
  end if;
  if p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'An amount must be more than zero' using errcode = '22023';
  end if;

  insert into public.transactions
    (kind, amount_minor, account_id, category_id, note, occurred_at, planned_id)
  values
    (v.kind, p_amount_minor, coalesce(p_account, v.account_id), v.category_id,
     v.name, p_paid_at, v.id)
  returning id into v_tx;

  update public.planned_payments
  set next_due = coalesce(p_next_due, next_due),
      done_at = case when p_next_due is null then now() else null end
  where id = v.id;

  return v_tx;
end;
$$;

revoke execute on function public.pay_planned_payment(uuid, bigint, timestamptz, uuid, date)
  from public, anon;
grant execute on function public.pay_planned_payment(uuid, bigint, timestamptz, uuid, date)
  to authenticated;
