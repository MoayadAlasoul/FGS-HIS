-- ===== generic approval guard: payment_records, expenses, reserve_usage, client1_payments =====
create or replace function app_private.approval_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare keep text[] := array['status','approved_by','approved_at','decision_note','override_reason','deleted_at','deleted_by'];
begin
  if auth.uid() is null then return new; end if;            -- service role / migrations only
  if app_private.my_role() is null then raise exception 'INACTIVE_USER'; end if;
  if tg_op = 'INSERT' then
    new.status := 'pending'; new.created_by := auth.uid();
    new.approved_by := null; new.approved_at := null; new.decision_note := null;
    new.deleted_at := null; new.deleted_by := null;
    if tg_table_name = 'expenses' then new.override_reason := null; end if;
    return new;
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_DELETE'; end if;
    new.deleted_by := auth.uid();
  end if;
  if new.status is distinct from old.status then
    if old.status <> 'pending' then raise exception 'ALREADY_DECIDED'; end if;
    if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_APPROVE'; end if;
    if old.created_by is not distinct from auth.uid() then raise exception 'SELF_APPROVAL_FORBIDDEN'; end if;
    if (to_jsonb(new) - keep) is distinct from (to_jsonb(old) - keep) then raise exception 'CANNOT_CHANGE_DATA_WHILE_DECIDING'; end if;
    new.approved_by := auth.uid(); new.approved_at := now();
  else
    if (to_jsonb(new) - keep) is distinct from (to_jsonb(old) - keep) then
      if old.status <> 'pending' then raise exception 'DECIDED_RECORD_IS_IMMUTABLE'; end if;
      if old.created_by is distinct from auth.uid() and not app_private.is_owner() then raise exception 'ONLY_CREATOR_CAN_EDIT'; end if;
    end if;
    new.status := old.status; new.approved_by := old.approved_by; new.approved_at := old.approved_at; new.created_by := old.created_by;
    if tg_table_name = 'expenses' and not app_private.is_owner() then new.override_reason := old.override_reason; end if;
  end if;
  return new;
end $$;

create trigger a_approval_guard before insert or update on public.payment_records for each row execute function app_private.approval_guard();
create trigger a_approval_guard before insert or update on public.expenses        for each row execute function app_private.approval_guard();
create trigger a_approval_guard before insert or update on public.reserve_usage    for each row execute function app_private.approval_guard();
create trigger a_approval_guard before insert or update on public.client1_payments for each row execute function app_private.approval_guard();

-- ===== financial validations (row-locked to be race-safe) =====
create or replace function app_private.validate_payment_record() returns trigger
language plpgsql security definer set search_path = '' as $$
declare total numeric; used numeric;
begin
  if new.deleted_at is not null or new.status = 'rejected' then return new; end if;
  perform 1 from public.payments where id = new.payment_id for update;
  select coalesce(sum(amount),0) into total from public.payment_items where payment_id = new.payment_id;
  select coalesce(sum(amount),0) into used from public.payment_records
   where payment_id = new.payment_id and deleted_at is null and status in ('pending','approved') and id <> new.id;
  if used + new.amount > total then raise exception 'PAYMENT_EXCEEDS_REMAINING: remaining %', total - used; end if;
  return new;
end $$;
create trigger b_validate before insert or update on public.payment_records for each row execute function app_private.validate_payment_record();

create or replace function app_private.validate_reserve_usage() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cap numeric; used numeric;
begin
  if new.deleted_at is not null or new.status = 'rejected' then return new; end if;
  select reserve_amount into cap from public.projects where id = new.project_id for update;
  select coalesce(sum(amount),0) into used from public.reserve_usage
   where project_id = new.project_id and deleted_at is null and status in ('pending','approved') and id <> new.id;
  if used + new.amount > cap then raise exception 'RESERVE_EXCEEDED: remaining %', cap - used; end if;
  return new;
end $$;
create trigger b_validate before insert or update on public.reserve_usage for each row execute function app_private.validate_reserve_usage();

create or replace function app_private.validate_client1_payment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cap numeric; used numeric;
begin
  if new.deleted_at is not null or new.status = 'rejected' then return new; end if;
  select client1_budget into cap from public.projects where id = new.project_id for update;
  select coalesce(sum(amount),0) into used from public.client1_payments
   where project_id = new.project_id and deleted_at is null and status in ('pending','approved') and id <> new.id;
  if used + new.amount > cap then raise exception 'CLIENT1_PAYMENT_EXCEEDS_BUDGET: remaining %', cap - used; end if;
  return new;
end $$;
create trigger b_validate before insert or update on public.client1_payments for each row execute function app_private.validate_client1_payment();

create or replace function app_private.validate_expense() returns trigger
language plpgsql security definer set search_path = '' as $$
declare ceil numeric; cur numeric; p record; was_approved boolean := false;
begin
  if tg_op = 'UPDATE' then was_approved := (old.status = 'approved'); end if;
  if new.status = 'approved' and not was_approved and new.deleted_at is null then
    select * into p from public.projects where id = new.project_id for update;
    if new.scope = 'product' then
      ceil := p.product_budget + coalesce((select sum(amount) from public.reserve_usage where project_id = p.id and status = 'approved' and deleted_at is null), 0);
    else
      ceil := p.client1_budget;
    end if;
    select coalesce(sum(amount),0) into cur from public.expenses
     where project_id = p.id and scope = new.scope and status = 'approved' and deleted_at is null and id <> new.id;
    if cur + new.amount > ceil and coalesce(trim(new.override_reason),'') = '' then
      raise exception 'EXCEEDS_BUDGET_OVERRIDE_REASON_REQUIRED: ceiling %, approved %, this %', ceil, cur, new.amount;
    end if;
  end if;
  return new;
end $$;
create trigger b_validate before insert or update on public.expenses for each row execute function app_private.validate_expense();

-- ===== payments: finance may only touch operational fields; approved structure is owner-only =====
create or replace function app_private.payments_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare keep text[] := array['due_date','due_flag','payee','ref','notes'];
begin
  if auth.uid() is null then return new; end if;
  if app_private.my_role() is null then raise exception 'INACTIVE_USER'; end if;
  if not app_private.is_owner() and (to_jsonb(new) - keep) is distinct from (to_jsonb(old) - keep) then
    raise exception 'ONLY_OWNER_CAN_CHANGE_APPROVED_PAYMENT_STRUCTURE';
  end if;
  if new.deleted_at is distinct from old.deleted_at then new.deleted_by := auth.uid(); end if;
  return new;
end $$;
create trigger a_guard before update on public.payments for each row execute function app_private.payments_guard();

-- ===== tasks: team member limited to progress/status; consistency rules =====
create or replace function app_private.tasks_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare keep text[] := array['progress','status','actual_start','actual_end']; changed boolean := true;
begin
  if tg_op = 'UPDATE' then
    changed := new.assignee_id is distinct from old.assignee_id;
    if auth.uid() is not null then
      if app_private.my_role() is null then raise exception 'INACTIVE_USER'; end if;
      if app_private.is_team() then
        if old.assignee_id is distinct from auth.uid() then raise exception 'NOT_YOUR_TASK'; end if;
        if (to_jsonb(new) - keep) is distinct from (to_jsonb(old) - keep) then raise exception 'TEAM_MEMBER_CAN_ONLY_UPDATE_PROGRESS_AND_STATUS'; end if;
      end if;
      if new.deleted_at is distinct from old.deleted_at then
        if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_DELETE'; end if;
        new.deleted_by := auth.uid();
      end if;
    end if;
  end if;
  if new.progress >= 100 then new.status := 'done'; new.actual_end := coalesce(new.actual_end, current_date);
  elsif new.progress > 0 and new.status in ('not_started','done') then new.status := 'in_progress';
  elsif new.progress = 0 and new.status = 'done' then new.status := 'not_started'; end if;
  if new.progress > 0 then new.actual_start := coalesce(new.actual_start, current_date); end if;
  if new.assignee_id is not null and changed then
    if not exists (select 1 from public.profiles where id = new.assignee_id and active) then raise exception 'ASSIGNEE_MUST_BE_AN_ACTIVE_USER'; end if;
  end if;
  return new;
end $$;
create trigger a_guard before insert or update on public.tasks for each row execute function app_private.tasks_guard();

-- ===== phase approval: owner / general manager only, only when all tasks are 100% =====
create or replace function app_private.phase_approval_validate() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then
    if not (app_private.is_owner() or app_private.is_gm()) then raise exception 'ONLY_OWNER_OR_GM_CAN_APPROVE_PHASES'; end if;
    new.approved_by := auth.uid(); new.revoked_at := null; new.revoked_by := null;
  end if;
  if exists (select 1 from public.tasks where phase_id = new.phase_id and deleted_at is null and progress < 100) then
    raise exception 'PHASE_HAS_INCOMPLETE_TASKS';
  end if;
  return new;
end $$;
create trigger a_validate before insert on public.phase_approvals for each row execute function app_private.phase_approval_validate();

create or replace function app_private.phase_approval_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then
    if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_REVOKE_APPROVAL'; end if;
    if (to_jsonb(new) - array['revoked_at','revoked_by']) is distinct from (to_jsonb(old) - array['revoked_at','revoked_by']) then
      raise exception 'APPROVAL_RECORD_IS_IMMUTABLE';
    end if;
    new.revoked_by := auth.uid();
  end if;
  return new;
end $$;
create trigger a_guard before update on public.phase_approvals for each row execute function app_private.phase_approval_guard();

-- ===== issues: general manager may only decide (status / resolution) =====
create or replace function app_private.issues_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return new; end if;
  if app_private.is_gm() and (to_jsonb(new) - array['status','resolution_note']) is distinct from (to_jsonb(old) - array['status','resolution_note']) then
    raise exception 'GM_CAN_ONLY_DECIDE_STATUS_AND_RESOLUTION';
  end if;
  if new.deleted_at is distinct from old.deleted_at then
    if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_DELETE'; end if;
    new.deleted_by := auth.uid();
  end if;
  return new;
end $$;
create trigger a_guard before update on public.issues for each row execute function app_private.issues_guard();

-- ===== soft-delete for the rest: owner only =====
create or replace function app_private.owner_only_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and new.deleted_at is distinct from old.deleted_at then
    if not app_private.is_owner() then raise exception 'ONLY_OWNER_CAN_DELETE'; end if;
    new.deleted_by := auth.uid();
  end if;
  return new;
end $$;
create trigger a_guard before update on public.phases      for each row execute function app_private.owner_only_delete();
create trigger a_guard before update on public.attachments for each row execute function app_private.owner_only_delete();

-- ===== audit log: every insert/update/delete, append-only =====
create or replace function app_private.audit_row() returns trigger
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); p record; rid text;
begin
  select email, role::text as role into p from public.profiles where id = uid;
  rid := case when tg_op = 'DELETE' then to_jsonb(old)->>'id' else to_jsonb(new)->>'id' end;
  insert into public.audit_log(user_id, user_email, user_role, action, table_name, record_id, old_data, new_data)
  values (uid, coalesce(p.email, 'system'), coalesce(p.role, 'system'), tg_op, tg_table_name, rid,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles','projects','phases','phase_costs','phase_approvals','payments','payment_items','payment_records',
                           'expenses','reserve_usage','client1_items','client1_payments','tasks','task_notes','issues','attachments','report_snapshots']
  loop
    execute format('create trigger z_audit after insert or update or delete on public.%I for each row execute function app_private.audit_row()', t);
  end loop;
end $$;

create or replace function app_private.audit_immutable() returns trigger language plpgsql as $$
begin raise exception 'AUDIT_LOG_IS_APPEND_ONLY'; end $$;
create trigger audit_no_update_delete before update or delete on public.audit_log for each row execute function app_private.audit_immutable();
create trigger audit_no_truncate before truncate on public.audit_log for each statement execute function app_private.audit_immutable();
