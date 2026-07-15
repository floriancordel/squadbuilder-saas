-- ============================================================
--  supabase/snapshots.sql — Historique de versions SquadBuilder
--  ADDITIF · IDEMPOTENT · ZÉRO perte. À exécuter UNE fois.
--  Une version figée = une copie immuable du blob `data` d'un projet,
--  horodatée et attribuée à son auteur. Restauration = réinjection via
--  le compare-and-swap `rev` existant (aucune écriture directe ici).
-- ============================================================

create table if not exists public.org_snapshots (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.organizations(id) on delete cascade,
  rev          integer not null default 0,          -- rev de l'org au moment du figeage
  label        text not null default '',            -- libellé libre ("Cible 2026", "avant réorg"…)
  data         jsonb not null,                      -- copie complète de l'org chart
  author_email text not null default '',
  created_at   timestamptz not null default now()
);
create index if not exists org_snapshots_org_idx on public.org_snapshots (org_id, created_at desc);

alter table public.org_snapshots enable row level security;

-- Lecture : tout membre du projet voit l'historique.
drop policy if exists snap_select on public.org_snapshots;
create policy snap_select on public.org_snapshots
  for select using (public.has_org_access(org_id));

-- Création : un éditeur du projet, et l'auteur déclaré doit être soi-même.
drop policy if exists snap_insert on public.org_snapshots;
create policy snap_insert on public.org_snapshots
  for insert with check (
    public.is_org_editor(org_id) and lower(author_email) = public.current_email()
  );

-- Suppression : un éditeur du projet peut élaguer l'historique.
drop policy if exists snap_delete on public.org_snapshots;
create policy snap_delete on public.org_snapshots
  for delete using (public.is_org_editor(org_id));

-- Pas de policy UPDATE : les versions sont IMMUABLES (RLS refuse par défaut).

-- Vérifications :
--   a) select relrowsecurity from pg_class where relname='org_snapshots';  -- true
--   b) select count(*) from pg_policies where tablename='org_snapshots';   -- 3
