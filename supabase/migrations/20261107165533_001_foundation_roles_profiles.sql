create schema if not exists app_private;
revoke all on schema app_private from public, anon;
grant usage on schema app_private to authenticated;

create type public.app_role as enum ('owner','general_manager','project_manager','finance','team_member');
create type public.approval_status as enum ('pending','approved','rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null default '',
  email text not null,
  role public.app_role not null default 'team_member',
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- role helpers (inactive users resolve to NULL role => no access anywhere)
create or replace function app_private.my_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid() and active
$$;
create or replace function app_private.is_owner() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() = 'owner', false) $$;
create or replace function app_private.is_gm() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() = 'general_manager', false) $$;
create or replace function app_private.is_pm() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() = 'project_manager', false) $$;
create or replace function app_private.is_fin() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() = 'finance', false) $$;
create or replace function app_private.is_team() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() = 'team_member', false) $$;
create or replace function app_private.is_mgmt() returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.my_role() in ('owner','general_manager','project_manager','finance'), false) $$;

revoke all on all functions in schema app_private from public, anon;
grant execute on all functions in schema app_private to authenticated;

-- a new auth user always starts as an INACTIVE team_member; role never comes from client metadata
create or replace function app_private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, email, full_name, role, active)
  values (new.id, coalesce(new.email,''), coalesce(new.raw_user_meta_data->>'full_name',''), 'team_member', false);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function app_private.handle_new_user();

create or replace function app_private.profiles_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not app_private.is_owner() then
    if new.role <> old.role or new.active <> old.active or new.email <> old.email or new.id <> old.id then
      raise exception 'ONLY_OWNER_CAN_CHANGE_ROLE_OR_ACTIVE';
    end if;
  end if;
  if old.role = 'owner' and old.active and (new.role <> 'owner' or not new.active) then
    if (select count(*) from public.profiles where role = 'owner' and active and id <> old.id) = 0 then
      raise exception 'LAST_OWNER_CANNOT_BE_REMOVED';
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger profiles_guard before update on public.profiles
  for each row execute function app_private.profiles_guard();
