-- Invoices: what the user has billed through Payoneer (or any account), and
-- whether it has been paid. Paying one logs the money as income on that
-- account, and the invoice remembers that transaction.

create table if not exists public.invoices (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid()
                      references auth.users (id) on delete cascade,
  account_id          uuid not null references public.accounts (id) on delete cascade,
  client              text not null check (char_length(btrim(client)) between 1 and 40),
  reference           text check (reference is null or char_length(reference) <= 40),
  amount_minor        bigint not null check (amount_minor > 0),
  issued_on           date not null default current_date,
  status              text not null default 'sent'
                      check (status in ('sent', 'paid', 'cancelled')),
  paid_transaction_id uuid references public.transactions (id) on delete set null,
  created_at          timestamptz not null default now()
);

create index if not exists invoices_user_issued_idx
  on public.invoices (user_id, issued_on desc);

comment on column public.invoices.amount_minor is
  'What was billed, in the account''s currency minor unit. What arrived can differ (fees): see the paid transaction.';

alter table public.invoices enable row level security;

drop policy if exists "Invoices: read own" on public.invoices;
drop policy if exists "Invoices: insert own" on public.invoices;
drop policy if exists "Invoices: update own" on public.invoices;
drop policy if exists "Invoices: delete own" on public.invoices;

create policy "Invoices: read own" on public.invoices
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Invoices: insert own" on public.invoices
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.accounts a
      where a.id = account_id and a.user_id = (select auth.uid())
    )
  );
create policy "Invoices: update own" on public.invoices
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Invoices: delete own" on public.invoices
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Deleting the income a paid invoice logged puts the invoice back to
-- "sent", so it never claims money that isn't recorded anywhere.
create or replace function public.invoices_unpay_on_unlink()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.paid_transaction_id is not null
     and new.paid_transaction_id is null
     and new.status = 'paid' then
    new.status := 'sent';
  end if;
  return new;
end;
$$;

drop trigger if exists invoices_unpay_on_unlink on public.invoices;
create trigger invoices_unpay_on_unlink
  before update on public.invoices
  for each row execute function public.invoices_unpay_on_unlink();

-- Marks an invoice paid and logs what arrived as income, in one step.
-- Runs as the caller, so row-level security still applies to both tables.
create or replace function public.mark_invoice_paid(
  p_invoice uuid,
  p_amount_minor bigint,
  p_paid_at timestamptz,
  p_category uuid,
  p_note text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account uuid;
  v_tx uuid;
begin
  select account_id into v_account
  from public.invoices
  where id = p_invoice and status = 'sent'
  for update;
  if v_account is null then
    raise exception 'Invoice not found or not waiting for payment'
      using errcode = 'P0002';
  end if;

  insert into public.transactions
    (kind, amount_minor, account_id, category_id, note, occurred_at)
  values
    ('income', p_amount_minor, v_account, p_category,
     nullif(btrim(p_note), ''), p_paid_at)
  returning id into v_tx;

  update public.invoices
  set status = 'paid', paid_transaction_id = v_tx
  where id = p_invoice;

  return v_tx;
end;
$$;

revoke execute on function public.mark_invoice_paid(uuid, bigint, timestamptz, uuid, text)
  from public, anon;
grant execute on function public.mark_invoice_paid(uuid, bigint, timestamptz, uuid, text)
  to authenticated;
