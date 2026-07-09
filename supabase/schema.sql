-- ============================================================
--  SquadBuilder — schéma Supabase (Postgres)
--  À coller dans Supabase > SQL Editor > New query > Run
-- ============================================================

-- Extension pour générer des UUID
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- Table des organisations : 1 org = 1 org chart (document JSON)
-- ------------------------------------------------------------
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'Mon organisation',
  data        jsonb not null default '{}'::jsonb,   -- l'org chart complet
  owner_email text not null,                        -- email du proprietaire
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Table des membres : acces d'equipe par email
--   role = 'owner' | 'editor' | 'viewer'
-- ------------------------------------------------------------
create table if not exists public.memberships (
  org_id  uuid not null references public.organizations(id) on delete cascade,
  email   text not null,
  role    text not null default 'editor',
  primary key (org_id, email)
);

create index if not exists memberships_email_idx on public.memberships (lower(email));

-- ------------------------------------------------------------
-- Helper : l'email de l'utilisateur connecté (depuis le JWT)
-- ------------------------------------------------------------
create or replace function public.current_email()
returns text language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

-- ------------------------------------------------------------
-- Helper : l'utilisateur a-t-il accès à cette org ?
-- ------------------------------------------------------------
create or replace function public.has_org_access(o_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
    where o.id = o_id and lower(o.owner_email) = public.current_email()
  ) or exists (
    select 1 from public.memberships m
    where m.org_id = o_id and lower(m.email) = public.current_email()
  );
$$;

create or replace function public.is_org_owner(o_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
    where o.id = o_id and lower(o.owner_email) = public.current_email()
  );
$$;

-- ------------------------------------------------------------
-- Trigger : maj automatique de updated_at
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists trg_org_touch on public.organizations;
create trigger trg_org_touch before update on public.organizations
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- Row Level Security
-- ------------------------------------------------------------
alter table public.organizations enable row level security;
alter table public.memberships   enable row level security;

-- organizations : lecture/écriture si owner ou membre ; création si on est le owner
drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations
  for select using (public.has_org_access(id));

drop policy if exists org_insert on public.organizations;
create policy org_insert on public.organizations
  for insert with check (lower(owner_email) = public.current_email());

drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations
  for update using (public.has_org_access(id)) with check (public.has_org_access(id));

drop policy if exists org_delete on public.organizations;
create policy org_delete on public.organizations
  for delete using (public.is_org_owner(id));

-- memberships : visibles par les membres ; gérées par le owner
drop policy if exists mem_select on public.memberships;
create policy mem_select on public.memberships
  for select using (public.has_org_access(org_id));

drop policy if exists mem_insert on public.memberships;
create policy mem_insert on public.memberships
  for insert with check (public.is_org_owner(org_id));

drop policy if exists mem_delete on public.memberships;
create policy mem_delete on public.memberships
  for delete using (public.is_org_owner(org_id));

-- ------------------------------------------------------------
-- Confort : à la création d'une org, ajouter le owner comme membre
-- ------------------------------------------------------------
create or replace function public.add_owner_membership()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.memberships(org_id, email, role)
  values (new.id, lower(new.owner_email), 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trg_org_owner_member on public.organizations;
create trigger trg_org_owner_member after insert on public.organizations
  for each row execute function public.add_owner_membership();
