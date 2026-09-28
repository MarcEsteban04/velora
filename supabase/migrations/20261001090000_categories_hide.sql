-- Velora: hide categories instead of deleting them.
-- A hidden category leaves the pickers but keeps its history and totals,
-- and can be restored. Deleting is only offered for unused categories.
alter table public.categories
  add column archived_at timestamptz;
