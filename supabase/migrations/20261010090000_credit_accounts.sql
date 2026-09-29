-- Credit accounts: a card or pay-later plan (BillEase) kept in Wallet. Its
-- balance is what's owed, below zero: spending on it takes it further
-- down, paying the bill (a transfer in) brings it back up. The limit is
-- optional, for what's still available.

alter table public.accounts drop constraint if exists accounts_type_check;
alter table public.accounts add constraint accounts_type_check
  check (type in ('cash', 'bank', 'eWallet', 'savings', 'credit'));

alter table public.accounts
  add column if not exists credit_limit_minor bigint
    check (credit_limit_minor is null or credit_limit_minor > 0);

