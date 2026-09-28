-- Which bank or e-wallet an account belongs to (for example 'maribank'), so
-- the app can show its logo and brand colours. The key maps to the app's
-- institution catalogue. NULL means none chosen; the app then falls back to
-- matching the account name.
alter table public.accounts
  add column institution text
    check (institution is null or institution ~ '^[a-z0-9_]{2,32}$');
