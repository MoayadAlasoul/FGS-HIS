-- ===== private attachments bucket (10 MB, pdf/png/jpeg), path = <entity_type>/<entity_id>/<file> =====
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attachments', 'attachments', false, 10485760, array['application/pdf','image/png','image/jpeg'])
on conflict (id) do nothing;

create or replace function app_private.storage_can_read(p text) returns boolean
language plpgsql stable set search_path = '' as $$
declare parts text[] := storage.foldername(p);
begin
  if array_length(parts,1) is distinct from 2 or parts[2] !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false; end if;
  return app_private.can_see_entity(parts[1], parts[2]::uuid);
end $$;
create or replace function app_private.storage_can_write(p text) returns boolean
language plpgsql stable set search_path = '' as $$
declare parts text[] := storage.foldername(p);
begin
  if array_length(parts,1) is distinct from 2 or parts[2] !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false; end if;
  return app_private.can_attach_entity(parts[1], parts[2]::uuid);
end $$;
grant execute on function app_private.storage_can_read(text), app_private.storage_can_write(text) to authenticated;

create policy att_obj_select on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and app_private.storage_can_read(name));
create policy att_obj_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and app_private.storage_can_write(name));
-- no update / delete policies: uploaded files are immutable

-- ===== realtime (RLS still applies to every event) =====
alter publication supabase_realtime add table
  public.payments, public.payment_records, public.expenses, public.reserve_usage, public.client1_payments,
  public.tasks, public.task_notes, public.phases, public.phase_approvals, public.issues, public.profiles;

-- ===== management dashboard: counts APPROVED records only; runs with the caller's RLS =====
create or replace function public.dashboard() returns jsonb
language plpgsql stable security invoker set search_path = '' as $$
declare p public.projects; r jsonb;
begin
  if not app_private.is_mgmt() then raise exception 'NOT_ALLOWED'; end if;
  select * into p from public.projects order by created_at limit 1;
  select jsonb_build_object(
    'budget', p.product_budget,
    'client1_budget', p.client1_budget,
    'reserve', p.reserve_amount,
    'reserve_used', coalesce((select sum(amount) from public.reserve_usage where status = 'approved' and deleted_at is null), 0),
    'reserve_pending', coalesce((select sum(amount) from public.reserve_usage where status = 'pending' and deleted_at is null), 0),
    'planned', coalesce((select sum(i.amount) from public.payment_items i join public.payments x on x.id = i.payment_id where x.deleted_at is null), 0),
    'paid', coalesce((select sum(amount) from public.payment_records where status = 'approved' and deleted_at is null), 0),
    'payments_pending', coalesce((select sum(amount) from public.payment_records where status = 'pending' and deleted_at is null), 0),
    'expenses_actual', coalesce((select sum(amount) from public.expenses where status = 'approved' and scope = 'product' and deleted_at is null), 0),
    'expenses_pending', coalesce((select sum(amount) from public.expenses where status = 'pending' and scope = 'product' and deleted_at is null), 0),
    'expenses_pending_count', (select count(*) from public.expenses where status = 'pending' and deleted_at is null),
    'client1_expenses', coalesce((select sum(amount) from public.expenses where status = 'approved' and scope = 'client1' and deleted_at is null), 0),
    'client1_paid', coalesce((select sum(amount) from public.client1_payments where status = 'approved' and deleted_at is null), 0),
    'client1_pending', coalesce((select sum(amount) from public.client1_payments where status = 'pending' and deleted_at is null), 0),
    'progress', coalesce((select round(avg(progress), 1) from public.tasks where deleted_at is null), 0),
    'tasks_total', (select count(*) from public.tasks where deleted_at is null),
    'tasks_done', (select count(*) from public.tasks where deleted_at is null and progress >= 100),
    'tasks_late', (select count(*) from public.tasks where deleted_at is null and progress < 100 and planned_end < current_date),
    'phases_total', (select count(*) from public.phases where deleted_at is null),
    'phases_approved', (select count(*) from public.phase_approvals where revoked_at is null),
    'payments', coalesce((select jsonb_agg(jsonb_build_object(
        'code', x.code, 'name', x.name, 'amount', t.total,
        'paid', coalesce(rc.paid, 0), 'pending', coalesce(rc.pend, 0), 'remaining', t.total - coalesce(rc.paid, 0)) order by x.seq)
      from public.payments x
      join lateral (select coalesce(sum(amount),0) total from public.payment_items where payment_id = x.id) t on true
      left join lateral (select sum(amount) filter (where status = 'approved') paid, sum(amount) filter (where status = 'pending') pend
                         from public.payment_records where payment_id = x.id and deleted_at is null) rc on true
      where x.deleted_at is null), '[]'::jsonb),
    'phases', coalesce((select jsonb_agg(jsonb_build_object(
        'code', f.code, 'name', f.name,
        'progress', coalesce((select round(avg(progress),1) from public.tasks where phase_id = f.id and deleted_at is null), 0),
        'approved', exists (select 1 from public.phase_approvals a where a.phase_id = f.id and a.revoked_at is null)) order by f.seq)
      from public.phases f where f.deleted_at is null), '[]'::jsonb)
  ) into r;
  return r;
end $$;
revoke all on function public.dashboard() from public, anon;
grant execute on function public.dashboard() to authenticated;
