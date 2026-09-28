-- Let users keep an account out of their net worth (for example a shared
-- household wallet or money held for someone else). Existing accounts
-- default to being included.
alter table public.accounts
  add column include_in_net_worth boolean not null default true;
