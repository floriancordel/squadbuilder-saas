// Edge Function : gestion des utilisateurs SquadBuilder (création / liste / retrait)
// Déploiement (une seule fois) :
//   npm i -g supabase
//   supabase login
//   supabase link --project-ref tinaakgjubesqwecnbuf
//   supabase functions deploy create-user
//
// La clé service_role est fournie automatiquement par Supabase (secret SUPABASE_SERVICE_ROLE_KEY).
// L'appelant DOIT être owner/admin de l'org concernée — vérifié via son JWT.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function genPassword(): string {
  const c = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
  const arr = new Uint32Array(14);
  crypto.getRandomValues(arr);
  return Array.from(arr, (n) => c[n % c.length]).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";

    // 1) Identifier l'appelant via son JWT
    const asUser = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return json({ error: "Non authentifié" }, 401);

    const admin = createClient(url, service);
    const body = await req.json().catch(() => ({}));
    const action = body.action || "create";
    const orgId = body.org_id;
    if (!orgId) return json({ error: "org_id manquant" }, 400);

    // 2) L'appelant doit pouvoir gérer les utilisateurs (owner/admin, ou permission users.manage)
    const { data: mem } = await admin
      .from("memberships").select("role, permissions")
      .eq("org_id", orgId).eq("email", (user.email || "").toLowerCase()).limit(1);
    const callerRole = mem?.[0]?.role;
    const callerPerms: string[] = mem?.[0]?.permissions || [];
    const canManage = callerRole === "owner" || callerRole === "admin" || callerPerms.includes("users.manage");
    if (!canManage) {
      return json({ error: "Action réservée à un administrateur de l'organisation" }, 403);
    }

    if (action === "list") {
      const { data: members } = await admin
        .from("memberships").select("email, role, permissions").eq("org_id", orgId);
      return json({ members: members || [] });
    }

    const email = (body.email || "").toLowerCase().trim();
    if (!email) return json({ error: "Email requis" }, 400);
    const ALL = ["org.edit", "roles.edit", "users.manage"];
    const permissions: string[] = Array.isArray(body.permissions) ? body.permissions.filter((p: string) => ALL.includes(p)) : [];
    const role = typeof body.role === "string" ? body.role : "viewer";

    if (action === "remove") {
      if (email === (user.email || "").toLowerCase()) return json({ error: "Vous ne pouvez pas retirer votre propre accès" }, 400);
      await admin.from("memberships").delete().eq("org_id", orgId).eq("email", email);
      return json({ ok: true });
    }

    if (action === "update") {
      // Modifier les droits d'un membre existant (pas le owner)
      const { data: target } = await admin.from("memberships").select("role").eq("org_id", orgId).eq("email", email).limit(1);
      if (target?.[0]?.role === "owner") return json({ error: "Le propriétaire ne peut pas être modifié" }, 400);
      await admin.from("memberships").update({ role, permissions }).eq("org_id", orgId).eq("email", email);
      return json({ ok: true, email, role, permissions });
    }

    // action === "create"
    const password = body.password || genPassword();
    const { error: cErr } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
    // Si le compte existe déjà, on continue quand même pour (ré)attribuer l'accès
    if (cErr && !/already been registered|already exists/i.test(cErr.message)) {
      return json({ error: cErr.message }, 400);
    }
    await admin.from("memberships").upsert({ org_id: orgId, email, role, permissions });
    return json({ ok: true, email, password, role, permissions, existed: !!cErr });
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
});
