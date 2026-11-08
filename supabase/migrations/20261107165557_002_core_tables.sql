create table public.projects (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  start_date date,
  product_budget numeric(14,2) not null check (product_budget >= 0),
  client1_budget numeric(14,2) not null check (client1_budget >= 0),
  reserve_pct numeric(5,2) not null check (reserve_pct between 0 and 100),
  reserve_amount numeric(14,2) generated always as (round(product_budget * reserve_pct / 100, 2)) stored,
  extra_integration_usd numeric(12,2) not null default 1500,
  fx_rate numeric(8,4) not null default 3.75,
  server_users int not null default 40,
  server_annual_cost numeric(14,2) not null default 8000,
  first_delivery_weeks int not null default 6,
  total_months int not null default 4,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create or replace function app_private.default_project() returns uuid
language sql stable security definer set search_path = '' as $$
  select id from public.projects order by created_at limit 1 $$;
grant execute on function app_private.default_project() to authenticated;

create table public.phases (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  code text unique not null,
  seq int not null,
  name text not null,
  week_from int, week_to int,
  owner_label text not null default '',
  description text not null default '',
  outputs text not null default '',
  approval_condition text not null default '',
  deleted_at timestamptz, deleted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid() references public.profiles(id)
);
create table public.phase_costs (            -- optional technical-phase cost (finance data, hidden from team members)
  phase_id uuid primary key references public.phases(id),
  cost numeric(14,2) not null default 0 check (cost >= 0)
);
create table public.phase_approvals (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references public.phases(id),
  approved_by uuid references public.profiles(id) default auth.uid(),
  approved_on date not null default current_date,
  doc_ref text not null default '',
  client_approver text not null default '',
  created_at timestamptz not null default now(),
  revoked_at timestamptz, revoked_by uuid references public.profiles(id)
);
create unique index phase_approvals_one_active on public.phase_approvals(phase_id) where revoked_at is null;

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  code text unique not null,
  seq int not null,
  name text not null,
  due_date date,
  due_flag boolean not null default false,
  payee text not null default '', ref text not null default '', notes text not null default '',
  linked_phase_id uuid references public.phases(id),
  deleted_at timestamptz, deleted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid() references public.profiles(id)
);
create table public.payment_items (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id),
  seq int not null,
  description text not null,
  amount numeric(14,2) not null check (amount >= 0),
  unique (payment_id, seq)
);
create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id),
  amount numeric(14,2) not null check (amount > 0),
  paid_date date not null default current_date,
  payee text not null default '', ref text not null default '', notes text not null default '',
  status public.approval_status not null default 'pending',
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id), approved_at timestamptz, decision_note text,
  deleted_at timestamptz, deleted_by uuid references public.profiles(id)
);
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  name text not null,
  category text not null default 'other',
  scope text not null default 'product' check (scope in ('product','client1')),
  phase_id uuid references public.phases(id),
  stage_payment_id uuid references public.payments(id),
  payee text not null default '',
  amount numeric(14,2) not null check (amount > 0),
  expense_date date not null default current_date,
  method text not null default '', ref text not null default '', notes text not null default '',
  status public.approval_status not null default 'pending',
  override_reason text,
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id), approved_at timestamptz, decision_note text,
  deleted_at timestamptz, deleted_by uuid references public.profiles(id)
);
create table public.reserve_usage (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  amount numeric(14,2) not null check (amount > 0),
  usage_date date not null default current_date,
  note text not null default '',
  status public.approval_status not null default 'pending',
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id), approved_at timestamptz, decision_note text,
  deleted_at timestamptz, deleted_by uuid references public.profiles(id)
);
create table public.client1_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  seq int not null, description text not null,
  amount numeric(14,2) not null check (amount >= 0),
  unique (project_id, seq)
);
create table public.client1_payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  amount numeric(14,2) not null check (amount > 0),
  paid_date date not null default current_date,
  payee text not null default '', ref text not null default '', notes text not null default '',
  status public.approval_status not null default 'pending',
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id), approved_at timestamptz, decision_note text,
  deleted_at timestamptz, deleted_by uuid references public.profiles(id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references public.phases(id),
  code text unique not null,
  seq int not null,
  title text not null,
  owner_label text not null default '',            -- original free-text owner from the plan
  assignee_id uuid references public.profiles(id), -- real assigned user
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  status text not null default 'not_started' check (status in ('not_started','in_progress','done','blocked')),
  progress int not null default 0 check (progress between 0 and 100),
  week_from int, week_to int,                      -- planned position in the plan (weeks)
  duration_text text,                              -- e.g. '7-10' days when no fixed week position
  planned_start date, planned_end date,
  actual_start date, actual_end date,
  acceptance_note text not null default '',
  deleted_at timestamptz, deleted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid() references public.profiles(id)
);
create index tasks_assignee_idx on public.tasks(assignee_id);
create index tasks_phase_idx on public.tasks(phase_id);
create table public.task_notes (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id),
  author_id uuid not null default auth.uid() references public.profiles(id),
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table public.issues (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null default app_private.default_project() references public.projects(id),
  code text unique not null,
  kind text not null check (kind in ('risk','conflict')),
  title text not null, details text not null default '',
  status text not null default 'open' check (status in ('open','in_progress','resolved')),
  resolution_note text not null default '',
  deleted_at timestamptz, deleted_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid() references public.profiles(id)
);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('task','expense','payment_record','client1_payment','issue')),
  entity_id uuid not null,
  storage_path text not null unique,
  file_name text not null, mime_type text, size_bytes bigint,
  uploaded_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  deleted_at timestamptz, deleted_by uuid references public.profiles(id)
);
create index attachments_entity_idx on public.attachments(entity_type, entity_id);

create table public.report_snapshots (
  id uuid primary key default gen_random_uuid(),
  report_type text not null,
  params jsonb not null default '{}'::jsonb,
  payload jsonb not null,
  generated_by uuid default auth.uid() references public.profiles(id),
  generated_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  user_id uuid, user_email text, user_role text,
  action text not null,
  table_name text not null, record_id text,
  old_data jsonb, new_data jsonb,
  legacy boolean not null default false, legacy_actor text
);
create index audit_log_table_idx on public.audit_log(table_name, at desc);
