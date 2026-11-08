-- First owner (run once). Do NOT commit real emails.
-- 1) Supabase Dashboard > Authentication > Users > Invite user  (the official owner email)
-- 2) The new account starts INACTIVE as team_member. Promote it in the SQL editor:
update public.profiles
   set role = 'owner', active = true, full_name = 'OWNER NAME'
 where email = 'OWNER_EMAIL@example.com';
-- 3) Authentication > Providers/Sign In: disable "Allow new users to sign up".
