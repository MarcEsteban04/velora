-- Credit lines on debts (cards, pay-later plans): the limit, and the
-- latest bill (what's due and when). Purchases can be split into monthly
-- installments.

alter table public.debts
  add column if not exists credit_limit_minor bigint
    check (credit_limit_minor is null or credit_limit_minor > 0),
  -- The latest bill: what it asked for, when it's due, and when it was
  -- set (payments after that count against it).
  add column if not exists bill_due_minor bigint
    check (bill_due_minor is null or bill_due_minor >= 0),
  add column if not exists bill_due_on date,
  add column if not exists bill_set_at timestamptz;

alter table public.debt_entries
  -- A purchase paid over this many months (1 is pay in full).
  add column if not exists installments smallint
    check (installments is null or installments between 1 and 60);
