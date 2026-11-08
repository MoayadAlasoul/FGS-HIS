create or replace function app_private.audit_immutable() returns trigger
language plpgsql set search_path = '' as $$
begin raise exception 'AUDIT_LOG_IS_APPEND_ONLY'; end $$;
