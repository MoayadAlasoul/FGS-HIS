-- Run on the source before a backup and on the restored database after: the two outputs must be identical.
select jsonb_build_object(
  'projects', (select count(*) from public.projects),
  'phases', (select count(*) from public.phases), 'tasks', (select count(*) from public.tasks),
  'payments', (select count(*) from public.payments), 'payment_items', (select count(*) from public.payment_items),
  'payment_records', (select count(*) from public.payment_records), 'expenses', (select count(*) from public.expenses),
  'reserve_usage', (select count(*) from public.reserve_usage), 'client1_payments', (select count(*) from public.client1_payments),
  'issues', (select count(*) from public.issues), 'audit_log', (select count(*) from public.audit_log),
  'product_budget', (select product_budget from public.projects limit 1),
  'reserve_amount', (select reserve_amount from public.projects limit 1),
  'client1_budget', (select client1_budget from public.projects limit 1),
  'payment_items_total', (select coalesce(sum(amount),0) from public.payment_items),
  'approved_payments_total', (select coalesce(sum(amount),0) from public.payment_records where status='approved' and deleted_at is null),
  'approved_expenses_total', (select coalesce(sum(amount),0) from public.expenses where status='approved' and deleted_at is null)
) as manifest;
