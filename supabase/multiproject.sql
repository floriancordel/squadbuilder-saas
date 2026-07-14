-- ============================================================
--  supabase/multiproject.sql — Multi-projets SquadBuilder
--  ADDITIF · IDEMPOTENT · ZÉRO perte. À coller dans Supabase > SQL Editor.
--  Les projets existants restent des lignes `organizations` (data jsonb intacte).
--  À exécuter UNE fois, AVANT de déployer le client multi-projets.
-- ============================================================

-- 1) Colonne rev pour le compare-and-swap (exigée par saveOrg ; absente de schema.sql).
--    Sans elle : le client retombe en last-write-wins (revSupported=false).
alter table public.organizations
  add column if not exists rev integer not null default 0;

-- 2) Backfill : garantir la membership 'owner' des projets déjà créés
--    (le trigger add_owner_membership ne s'exécute qu'à l'INSERT).
insert into public.memberships(org_id, email, role)
  select id, lower(owner_email), 'owner' from public.organizations
  on conflict do nothing;

-- 3) Préférences PAR UTILISATEUR : dossiers imbriqués + placement projet→dossier.
--    Vue strictement personnelle (RLS privée). folders = arbre plat
--    [{id,name,parentId}] ; placement = { "<org_id>": "<folder_id|null>" }.
create table if not exists public.user_prefs (
  email      text primary key,
  folders    jsonb not null default '[]'::jsonb,
  placement  jsonb not null default '{}'::jsonb,
  last_org   uuid,
  updated_at timestamptz not null default now()
);
alter table public.user_prefs enable row level security;

drop policy if exists up_rw on public.user_prefs;
create policy up_rw on public.user_prefs
  for all
  using (lower(email) = public.current_email())
  with check (lower(email) = public.current_email());

drop trigger if exists trg_prefs_touch on public.user_prefs;
create trigger trg_prefs_touch before update on public.user_prefs
  for each row execute function public.touch_updated_at();

-- 4) Vérifications (non destructives) :
--    a) select column_name from information_schema.columns
--         where table_name='organizations' and column_name='rev';               -- 1 ligne
--    b) select o.id from public.organizations o
--         left join public.memberships m on m.org_id=o.id and m.role='owner'
--           and lower(m.email)=lower(o.owner_email) where m.org_id is null;      -- 0 ligne
--    c) select relrowsecurity from pg_class where relname='user_prefs';          -- true
