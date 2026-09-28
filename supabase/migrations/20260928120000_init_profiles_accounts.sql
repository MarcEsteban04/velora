-- Velora: initial schema, with profiles, accounts and atomic onboarding.
-- Every table is protected by row-level security, so users (including
-- anonymous ones) can only ever see and change their own rows.

-- ---------------------------------------------------------------------------
-- Profiles: one row per user, created when onboarding finishes.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null check (char_length(btrim(display_name)) between 1 and 24),
  currency_code char(3) not null check (currency_code ~ '^[A-Z]{3}$'),
  coach_tone    text not null default 'balanced'
                check (coach_tone in ('gentle', 'balanced', 'direct')),
  onboarded_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profiles is 'Velora user profile; its existence means onboarding is complete.';

-- ---------------------------------------------------------------------------
-- Accounts: cash, bank, e-wallet or savings. Money is stored in minor units.
-- ---------------------------------------------------------------------------
create table public.accounts (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null default auth.uid()
                        references auth.users (id) on delete cascade,
  name                  text not null check (char_length(btrim(name)) between 1 and 40),
  type                  text not null check (type in ('cash', 'bank', 'eWallet', 'savings')),
  currency_code         char(3) not null check (currency_code ~ '^[A-Z]{3}$'),
  opening_balance_minor bigint not null default 0,
  created_at            timestamptz not null default now()
);

create index accounts_user_id_created_at_idx on public.accounts (user_id, created_at);

comment on column public.accounts.opening_balance_minor is
  'Starting balance in the currency''s minor unit (for example centavos). Never a float.';

-- ---------------------------------------------------------------------------
-- Keep updated_at honest.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row-level security. `(select auth.uid())` is evaluated once per query
-- instead of once per row (Supabase performance guidance).
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.accounts enable row level security;

create policy "Profiles: read own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "Profiles: insert own" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "Profiles: update own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Accounts: read own" on public.accounts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Accounts: insert own" on public.accounts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Accounts: update own" on public.accounts
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Accounts: delete own" on public.accounts
  for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- complete_onboarding: saves the profile and first account in ONE
-- transaction, so there are never half-finished users. It's safe to retry: if
-- the network drops after success, calling again won't duplicate the account.
-- It runs as the caller (security invoker), so RLS still applies.
-- ---------------------------------------------------------------------------
create or replace function public.complete_onboarding(
  p_display_name          text,
  p_currency_code         text,
  p_coach_tone            text,
  p_account_name          text,
  p_account_type          text,
  p_opening_balance_minor bigint
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  insert into public.profiles (id, display_name, currency_code, coach_tone)
  values (v_user, btrim(p_display_name), p_currency_code, p_coach_tone)
  on conflict (id) do update
    set display_name  = excluded.display_name,
        currency_code = excluded.currency_code,
        coach_tone    = excluded.coach_tone;

  if not exists (select 1 from public.accounts where user_id = v_user) then
    insert into public.accounts (user_id, name, type, currency_code, opening_balance_minor)
    values (v_user, btrim(p_account_name), p_account_type, p_currency_code, p_opening_balance_minor);
  end if;
end;
$$;

revoke execute on function public.complete_onboarding(text, text, text, text, text, bigint) from public, anon;
grant execute on function public.complete_onboarding(text, text, text, text, text, bigint) to authenticated;
