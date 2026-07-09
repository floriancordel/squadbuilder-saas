-- ============================================================
--  Contrôle d'accès lecture/écriture (à coller dans Supabase > SQL Editor)
--  Optionnel mais recommandé : empêche les "viewer" d'écrire côté base.
-- ============================================================

create or replace function public.is_org_editor(o_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
    where o.id = o_id and lower(o.owner_email) = public.current_email()
  ) or exists (
    select 1 from public.memberships m
    where m.org_id = o_id and lower(m.email) = public.current_email()
      and m.role in ('owner','admin','editor')
  );
$$;

-- Lecture : tout membre (owner/admin/editor/viewer). Écriture : editor et plus.
drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations
  for update using (public.is_org_editor(id)) with check (public.is_org_editor(id));
