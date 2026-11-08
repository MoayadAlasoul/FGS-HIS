-- ===== grants: anon gets nothing; signed-in users cannot hard-delete anything =====
revoke all on all tables in schema public from anon;
revoke delete, truncate, references, trigger on all tables in schema public from authenticated;
revoke insert, update on public.audit_log from authenticated;
alter default privileges in schema public revoke all on tables from anon;

alter table public.profiles          enable row level security;
alter table public.projects          enable row level security;
alter table public.phases            enable row level security;
alter table public.phase_costs       enable row level security;
alter table public.phase_approvals   enable row level security;
alter table public.payments          enable row level security;
alter table public.payment_items     enable row level security;
alter table public.payment_records   enable row level security;
alter table public.expenses          enable row level security;
alter table public.reserve_usage     enable row level security;
alter table public.client1_items     enable row level security;
alter table public.client1_payments  enable row level security;
alter table public.tasks             enable row level security;
alter table public.task_notes        enable row level security;
alter table public.issues            enable row level security;
alter table public.attachments       enable row level security;
alter table public.report_snapshots  enable row level security;
alter table public.audit_log         enable row level security;

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select app_private.is_mgmt()));
create policy profiles_update on public.profiles for update to authenticated
  using ((select app_private.is_owner()) or id = (select auth.uid()))
  with check ((select app_private.is_owner()) or id = (select auth.uid()));

-- projects
create policy projects_select on public.projects for select to authenticated using ((select app_private.is_mgmt()));
create policy projects_update on public.projects for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));

-- tasks / phases (team members: only their own tasks and the phase name those tasks belong to)
create policy tasks_select on public.tasks for select to authenticated using (
  (deleted_at is null or (select app_private.is_owner()))
  and ((select app_private.is_mgmt()) or ((select app_private.is_team()) and assignee_id = (select auth.uid()))));
create policy tasks_insert on public.tasks for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_pm()));
create policy tasks_update on public.tasks for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_pm()) or ((select app_private.is_team()) and assignee_id = (select auth.uid())))
  with check ((select app_private.is_owner()) or (select app_private.is_pm()) or ((select app_private.is_team()) and assignee_id = (select auth.uid())));

create policy phases_select on public.phases for select to authenticated using (
  (deleted_at is null or (select app_private.is_owner()))
  and ((select app_private.is_mgmt())
       or ((select app_private.is_team()) and exists (select 1 from public.tasks t where t.phase_id = phases.id and t.assignee_id = (select auth.uid())))));
create policy phases_insert on public.phases for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_pm()));
create policy phases_update on public.phases for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_pm()))
  with check ((select app_private.is_owner()) or (select app_private.is_pm()));

create policy task_notes_select on public.task_notes for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_notes.task_id));
create policy task_notes_insert on public.task_notes for insert to authenticated
  with check (author_id = (select auth.uid()) and exists (select 1 from public.tasks t where t.id = task_notes.task_id));

create policy phase_costs_select on public.phase_costs for select to authenticated using ((select app_private.is_mgmt()));
create policy phase_costs_insert on public.phase_costs for insert to authenticated with check ((select app_private.is_owner()));
create policy phase_costs_update on public.phase_costs for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));

create policy phase_appr_select on public.phase_approvals for select to authenticated using ((select app_private.is_mgmt()));
create policy phase_appr_insert on public.phase_approvals for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_gm()));
create policy phase_appr_update on public.phase_approvals for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));

-- finance data (never visible to team members)
create policy payments_select on public.payments for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy payments_update on public.payments for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_fin()))
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));
create policy payment_items_select on public.payment_items for select to authenticated using ((select app_private.is_mgmt()));
create policy payment_items_insert on public.payment_items for insert to authenticated with check ((select app_private.is_owner()));
create policy payment_items_update on public.payment_items for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));

create policy pay_rec_select on public.payment_records for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy pay_rec_insert on public.payment_records for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));
create policy pay_rec_update on public.payment_records for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_fin()))
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));

create policy exp_select on public.expenses for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy exp_insert on public.expenses for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_fin()) or (select app_private.is_pm()));
create policy exp_update on public.expenses for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_fin()) or (select app_private.is_pm()))
  with check ((select app_private.is_owner()) or (select app_private.is_fin()) or (select app_private.is_pm()));

create policy reserve_select on public.reserve_usage for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy reserve_insert on public.reserve_usage for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));
create policy reserve_update on public.reserve_usage for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_fin()))
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));

create policy c1_items_select on public.client1_items for select to authenticated using ((select app_private.is_mgmt()));
create policy c1_items_insert on public.client1_items for insert to authenticated with check ((select app_private.is_owner()));
create policy c1_items_update on public.client1_items for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));
create policy c1_pay_select on public.client1_payments for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy c1_pay_insert on public.client1_payments for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));
create policy c1_pay_update on public.client1_payments for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_fin()))
  with check ((select app_private.is_owner()) or (select app_private.is_fin()));

-- issues
create policy issues_select on public.issues for select to authenticated
  using ((select app_private.is_mgmt()) and (deleted_at is null or (select app_private.is_owner())));
create policy issues_insert on public.issues for insert to authenticated
  with check ((select app_private.is_owner()) or (select app_private.is_pm()));
create policy issues_update on public.issues for update to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_pm()) or (select app_private.is_gm()))
  with check ((select app_private.is_owner()) or (select app_private.is_pm()) or (select app_private.is_gm()));

-- reports + audit
create policy reports_select on public.report_snapshots for select to authenticated using ((select app_private.is_mgmt()));
create policy reports_insert on public.report_snapshots for insert to authenticated
  with check ((select app_private.is_mgmt()) and generated_by = (select auth.uid()));
create policy audit_select on public.audit_log for select to authenticated
  using ((select app_private.is_owner()) or (select app_private.is_gm()));

-- attachments (rows) : visibility follows the parent record
create or replace function app_private.can_see_entity(etype text, eid uuid) returns boolean
language sql stable set search_path = '' as $$
  select case etype
    when 'task' then exists (select 1 from public.tasks t where t.id = eid)
    else app_private.is_mgmt() end
$$;
create or replace function app_private.can_attach_entity(etype text, eid uuid) returns boolean
language sql stable set search_path = '' as $$
  select case etype
    when 'task' then exists (select 1 from public.tasks t where t.id = eid)
                     and (app_private.is_owner() or app_private.is_pm() or app_private.is_team())
    when 'expense' then (app_private.is_owner() or app_private.is_fin() or app_private.is_pm())
                        and exists (select 1 from public.expenses e where e.id = eid)
    when 'payment_record' then (app_private.is_owner() or app_private.is_fin())
                        and exists (select 1 from public.payment_records r where r.id = eid)
    when 'client1_payment' then (app_private.is_owner() or app_private.is_fin())
                        and exists (select 1 from public.client1_payments r where r.id = eid)
    when 'issue' then (app_private.is_owner() or app_private.is_pm())
                        and exists (select 1 from public.issues i where i.id = eid)
    else false end
$$;
grant execute on function app_private.can_see_entity(text, uuid), app_private.can_attach_entity(text, uuid) to authenticated;

create policy att_select on public.attachments for select to authenticated
  using ((deleted_at is null or (select app_private.is_owner())) and app_private.can_see_entity(entity_type, entity_id));
create policy att_insert on public.attachments for insert to authenticated
  with check (uploaded_by = (select auth.uid()) and app_private.can_attach_entity(entity_type, entity_id));
create policy att_update on public.attachments for update to authenticated
  using ((select app_private.is_owner())) with check ((select app_private.is_owner()));
