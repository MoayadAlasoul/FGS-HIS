-- RLS smoke test. Runs in ONE transaction that is aborted at the end (nothing is saved).
-- Creates temporary auth users inside the transaction only. Run on a project that already has migrations 001..007.
begin;
create schema zz_test; grant usage on schema zz_test to anon, authenticated;
create table zz_test.res(n serial, label text, result text, detail text);
grant all on zz_test.res to anon, authenticated; grant usage on all sequences in schema zz_test to anon, authenticated;
create function zz_test.as_user(u uuid) returns void language plpgsql as $f$ begin
  perform set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u::text, true); execute 'set local role authenticated'; end $f$;
create function zz_test.as_su() returns void language plpgsql as $f$ begin execute 'reset role'; end $f$;
create function zz_test.chk(lbl text, q text, expect text) returns void language plpgsql as $f$
declare n int := 0; ok boolean := true; msg text := '';
begin begin execute q; get diagnostics n = row_count; exception when others then ok := false; msg := sqlerrm; end;
  insert into zz_test.res(label,result,detail) values (lbl, case when expect='allow' and ok and n>=1 then 'PASS' when expect='deny' and (not ok or n=0) then 'PASS' else 'FAIL' end, left(coalesce(nullif(msg,''),'rows='||n),90)); end $f$;
create function zz_test.cnt(lbl text, q text, expected bigint) returns void language plpgsql as $f$
declare n bigint; msg text := '';
begin begin execute q into n; exception when others then n := -1; msg := left(sqlerrm,70); end;
  insert into zz_test.res(label,result,detail) values (lbl, case when n=expected then 'PASS' else 'FAIL' end, 'got='||n||' expected='||expected||' '||msg); end $f$;

insert into auth.users(id,aud,role,email) values
 ('00000000-0000-0000-0000-0000000000a1','authenticated','authenticated','owner@zz-test.invalid'),
 ('00000000-0000-0000-0000-0000000000a2','authenticated','authenticated','gm@zz-test.invalid'),
 ('00000000-0000-0000-0000-0000000000a3','authenticated','authenticated','pm@zz-test.invalid'),
 ('00000000-0000-0000-0000-0000000000a4','authenticated','authenticated','fin@zz-test.invalid'),
 ('00000000-0000-0000-0000-0000000000a5','authenticated','authenticated','teama@zz-test.invalid'),
 ('00000000-0000-0000-0000-0000000000a6','authenticated','authenticated','teamb@zz-test.invalid');
update public.profiles set role='owner', active=true where id='00000000-0000-0000-0000-0000000000a1';
update public.profiles set role='general_manager', active=true where id='00000000-0000-0000-0000-0000000000a2';
update public.profiles set role='project_manager', active=true where id='00000000-0000-0000-0000-0000000000a3';
update public.profiles set role='finance', active=true where id='00000000-0000-0000-0000-0000000000a4';
update public.profiles set role='team_member', active=true where id in ('00000000-0000-0000-0000-0000000000a5','00000000-0000-0000-0000-0000000000a6');
update public.tasks set assignee_id='00000000-0000-0000-0000-0000000000a5' where code='T27';

select zz_test.as_user('00000000-0000-0000-0000-0000000000a5');
select zz_test.cnt('team: no payments', 'select count(*) from public.payments', 0);
select zz_test.cnt('team: no expenses', 'select count(*) from public.expenses', 0);
select zz_test.cnt('team: no audit', 'select count(*) from public.audit_log', 0);
select zz_test.cnt('team: only own task', 'select count(*) from public.tasks', 1);
select zz_test.chk('team: progress on own task', $s$update public.tasks set progress=50 where code='T27'$s$, 'allow');
select zz_test.chk('team: cannot edit title', $s$update public.tasks set title='x' where code='T27'$s$, 'deny');
select zz_test.chk('team: cannot self-promote', $s$update public.profiles set role='owner' where id='00000000-0000-0000-0000-0000000000a5'$s$, 'deny');
select zz_test.chk('team: dashboard denied', 'select public.dashboard()', 'deny');
select zz_test.as_user('00000000-0000-0000-0000-0000000000a4');
select zz_test.cnt('finance sees 4 payments', 'select count(*) from public.payments', 4);
select zz_test.chk('finance records payment (pending)', $s$insert into public.payment_records(payment_id,amount,ref) values ((select id from public.payments where code='P1'),1000,'T1')$s$, 'allow');
select zz_test.chk('finance cannot approve', $s$update public.payment_records set status='approved' where ref='T1'$s$, 'deny');
select zz_test.chk('finance cannot overpay P1', $s$insert into public.payment_records(payment_id,amount,ref) values ((select id from public.payments where code='P1'),17000,'T2')$s$, 'deny');
select zz_test.chk('finance cannot edit budget', $s$update public.projects set product_budget=1$s$, 'deny');
select zz_test.as_user('00000000-0000-0000-0000-0000000000a2');
select zz_test.chk('GM cannot approve payment', $s$update public.payment_records set status='approved' where ref='T1'$s$, 'deny');
select zz_test.as_user('00000000-0000-0000-0000-0000000000a1');
select zz_test.cnt('paid=0 before approval', $s$select ((public.dashboard()->>'paid')::numeric)::bigint$s$, 0);
select zz_test.chk('owner approves finance record', $s$update public.payment_records set status='approved' where ref='T1'$s$, 'allow');
select zz_test.cnt('paid=1000 after approval', $s$select ((public.dashboard()->>'paid')::numeric)::bigint$s$, 1000);
select zz_test.chk('owner records own', $s$insert into public.payment_records(payment_id,amount,ref) values ((select id from public.payments where code='P2'),500,'T3')$s$, 'allow');
select zz_test.chk('owner cannot self-approve', $s$update public.payment_records set status='approved' where ref='T3'$s$, 'deny');
select zz_test.chk('no hard delete', $s$delete from public.payments where code='P4'$s$, 'deny');
select zz_test.chk('audit log immutable', $s$update public.audit_log set action='x'$s$, 'deny');
select zz_test.cnt('constants: budget/reserve/client1', $s$select (product_budget=95750 and reserve_amount=19150 and client1_budget=35000)::int from public.projects$s$, 1);
select zz_test.cnt('payment items total = 95750', $s$select sum(amount)::bigint from public.payment_items$s$, 95750);
select zz_test.as_su();
do $r$ declare s text; p int; f int; begin
  select count(*) filter (where result='PASS'), count(*) filter (where result='FAIL') into p,f from zz_test.res;
  select string_agg(result||' | '||label||' | '||detail, E'\n' order by n) into s from zz_test.res;
  raise exception E'RESULTS pass=% fail=%\n%', p, f, s; end $r$;
