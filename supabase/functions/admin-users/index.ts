import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

const ROLES = ["owner", "general_manager", "project_manager", "finance", "team_member"];
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // lives only inside Supabase, never in the browser
    const authHeader = req.headers.get("Authorization") ?? "";

    // the caller acts with HIS OWN token, so every profile change is audited under his identity
    const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "unauthenticated" }, 401);

    const { data: me } = await caller.from("profiles").select("role,active").eq("id", user.id).single();
    if (!me || me.role !== "owner" || !me.active) return json({ error: "only_owner" }, 403);

    const admin = createClient(url, service, { auth: { autoRefreshToken: false, persistSession: false } });
    const body = await req.json();
    const action = body.action;

    if (action === "invite") {
  const email = String(body.email ?? "").trim().toLowerCase();
  const full_name = String(body.full_name ?? "").trim().slice(0, 120);
  const role = String(body.role ?? "");

  if (!EMAIL.test(email)) return json({ error: "invalid_email" }, 400);
  if (!ROLES.includes(role)) return json({ error: "invalid_role" }, 400);

  const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name },
    redirectTo: "https://legendary-sopapillas-d8915c.netlify.app/"
  });

  if (error || !data?.user) {
    return json({ error: error?.message ?? "invite_failed" }, 400);
  }

  const { error: e2 } = await caller.from("profiles")
    .update({ role, active: true, full_name })
    .eq("id", data.user.id);

  if (e2) return json({ error: e2.message }, 400);

  return json({ ok: true, user_id: data.user.id });
}

    if (action === "set_role") {
      const role = String(body.role ?? "");
      if (!ROLES.includes(role) || !body.user_id) return json({ error: "bad_request" }, 400);
      const { error } = await caller.from("profiles").update({ role }).eq("id", body.user_id);
      return error ? json({ error: error.message }, 400) : json({ ok: true });
    }

    if (action === "set_active") {
      if (!body.user_id || typeof body.active !== "boolean") return json({ error: "bad_request" }, 400);
      if (body.user_id === user.id && body.active === false) return json({ error: "cannot_deactivate_yourself" }, 400);
      const { error } = await caller.from("profiles").update({ active: body.active }).eq("id", body.user_id);
      if (error) return json({ error: error.message }, 400);
      // also block sign-in at the auth layer while deactivated
      const { error: e3 } = await admin.auth.admin.updateUserById(body.user_id, { ban_duration: body.active ? "none" : "876000h" });
      return e3 ? json({ error: e3.message }, 400) : json({ ok: true });
    }

    return json({ error: "unknown_action" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 500);
  }
});
