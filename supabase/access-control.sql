-- ============================================================
--  SquadBuilder — droits & permissions (SQL Editor > Run)
--  À exécuter une fois. Ajoute la colonne permissions et applique
--  le contrôle d'accès en écriture basé sur les permissions.
-- ============================================================

-- 1) Permissions par membre (tableau de clés : 'org.edit', 'roles.edit', 'users.manage')
alter table public.memberships
  add column if not exists permissions jsonb not null default '[]'::jsonb;

-- 2) Un membre peut-il ÉCRIRE dans l'organisation ?
--    owner, ou permission d'édition (org.edit / roles.edit),
--    ou rôle historique editor/admin/contributor.
create or replace function public.is_org_editor(o_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
    where o.id = o_id and lower(o.owner_email) = public.current_email()
  ) or exists (
    select 1 from public.memberships m
    where m.org_id = o_id and lower(m.email) = public.current_email()
      and (
        m.role in ('owner','admin','editor','contributor')
        or m.permissions ? 'org.edit'
        or m.permissions ? 'roles.edit'
      )
  );
$$;

-- Lecture : tout membre. Écriture : éditeurs (ci-dessus). Les "Lecteur" ne peuvent pas écrire.
drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations
  for update using (public.is_org_editor(id)) with check (public.is_org_editor(id));
