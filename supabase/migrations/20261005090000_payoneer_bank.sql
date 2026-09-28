-- Payoneer is an international bank, not an e-wallet: move accounts made
-- while the app listed it under e-wallets.
update public.accounts
set type = 'bank'
where type = 'eWallet'
  and (institution = 'payoneer' or lower(name) ~ '\mpayoneer\M');
