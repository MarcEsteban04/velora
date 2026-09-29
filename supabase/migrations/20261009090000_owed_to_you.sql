-- Owed to you: money the user lent someone. What's still owed comes from
-- owed_entries: lent (negative) and paid back (positive), like debts the
-- other way round.

create table if not exists public.owed (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  -- Who owes it.
  name           text not null check (char_length(btrim(name)) between 1 and 32),
  -- What it was for.
  note           text check (note is null or char_length(note) <= 80),
  currency_code  text not null check (currency_code ~ '^[A-Z]{3}$'),
  -- When they said they'd pay it back, if they did.
  due_on         date,
  created_at     timestamptz not null default now()
);

create index if not exists owed_user_idx on public.owed (user_id, created_at);

alter table public.owed enable row level security;

drop policy if exists "Owed: read own" on public.owed;
drop policy if exists "Owed: insert own" on public.owed;
drop policy if exists "Owed: update own" on public.owed;
drop policy if exists "Owed: delete own" on public.owed;
create policy "Owed: read own" on public.owed
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owed: insert own" on public.owed
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Owed: update own" on public.owed
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Owed: delete own" on public.owed
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.owed_entries (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  owed_id         uuid not null references public.owed (id) on delete cascade,
  -- Paid back (positive) or lent (negative), in the owed's currency.
  amount_minor    bigint not null check (amount_minor <> 0),
  note            text check (note is null or char_length(note) <= 80),
  occurred_at     timestamptz not null default now(),
  -- The expense (lent from an account) or income (paid back into one).
  transaction_id  uuid references public.transactions (id) on delete set null,
  created_at      timestamptz not null default now()
);

create index if not exists owed_entries_owed_idx
  on public.owed_entries (owed_id, occurred_at desc);

alter table public.owed_entries enable row level security;

drop policy if exists "Owed entries: read own" on public.owed_entries;
drop policy if exists "Owed entries: insert own" on public.owed_entries;
drop policy if exists "Owed entries: delete own" on public.owed_entries;
create policy "Owed entries: read own" on public.owed_entries
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Owed entries: insert own" on public.owed_entries
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.owed o
      where o.id = owed_id and o.user_id = (select auth.uid())
    )
  );
create policy "Owed entries: delete own" on public.owed_entries
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Lent (negative) or paid back (positive), in one step: the entry, and
-- when it moved an account, the expense or income too. Runs as the
-- caller, so row-level security applies. Returns the entry's id.
create or replace function public.record_owed_entry(
  p_owed uuid,
  p_amount_minor bigint,
  p_at timestamptz,
  p_account uuid,
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
  if p_amount_minor is null or p_amount_minor = 0 then
    raise exception 'The amount can''t be zero' using errcode = '22023';
  end if;
  select name into v_name from public.owed where id = p_owed;
  if v_name is null then
    raise exception 'Not found' using errcode = 'P0002';
  end if;

  if p_account is not null then
    insert into public.transactions
      (kind, amount_minor, account_id, note, occurred_at)
    values
      (case when p_amount_minor > 0 then 'income' else 'expense' end,
       abs(p_amount_minor), p_account,
       case when p_amount_minor > 0 then v_name || ' paid you back'
            else 'Lent to ' || v_name end,
       p_at)
    returning id into v_tx;
  end if;

  insert into public.owed_entries
    (owed_id, amount_minor, note, occurred_at, transaction_id)
  values
    (p_owed, p_amount_minor, nullif(btrim(p_note), ''), p_at, v_tx)
  returning id into v_entry;

  return v_entry;
end;
$$;

revoke execute on function public.record_owed_entry(uuid, bigint, timestamptz, uuid, text)
  from public, anon;
grant execute on function public.record_owed_entry(uuid, bigint, timestamptz, uuid, text)
  to authenticated;

-- Someone new who owes you, with what you lent them, all or nothing.
-- Returns the owed's id.
create or replace function public.create_owed(
  p_name text,
  p_note text,
  p_currency text,
  p_due_on date,
  p_amount_minor bigint,
  p_at timestamptz,
  p_account uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owed uuid;
begin
  if p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'What you lent must be more than zero' using errcode = '22023';
  end if;
  insert into public.owed (name, note, currency_code, due_on)
  values (btrim(p_name), nullif(btrim(p_note), ''), p_currency, p_due_on)
  returning id into v_owed;
  perform public.record_owed_entry(v_owed, -p_amount_minor, p_at, p_account, null);
  return v_owed;
end;
$$;

revoke execute on function public.create_owed(text, text, text, date, bigint, timestamptz, uuid)
  from public, anon;
grant execute on function public.create_owed(text, text, text, date, bigint, timestamptz, uuid)
  to authenticated;
