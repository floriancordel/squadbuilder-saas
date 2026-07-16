-- ============================================================
--  supabase/app-perms.sql — Droits globaux par compte (niveau application)
--  ADDITIF · IDEMPOTENT. Complète les droits PAR PROJET (memberships) par des
--  droits GLOBAUX : qui peut créer des projets, qui administre la plateforme.
--  Appliqué en DB (policy org_insert) — le client ne fait que refléter.
-- ============================================================

create table if not exists public.app_perms (
  email               text primary key,
  can_create_projects boolean not null default true,
  is_platform_admin   boolean not null default false,
  updated_at          timestamptz not null default now()
);
alter table public.app_perms enable row level security;

-- Un admin plateforme gère les droits globaux de tous les comptes.
create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.app_perms
    where lower(email) = public.current_email() and is_platform_admin
  );
$$;

drop policy if exists ap_select on public.app_perms;
create policy ap_select on public.app_perms
  for select using (lower(email) = public.current_email() or public.is_platform_admin());

drop policy if exists ap_write on public.app_perms;
create policy ap_write on public.app_perms
  for all using (public.is_platform_admin()) with check (public.is_platform_admin());

drop trigger if exists trg_app_perms_touch on public.app_perms;
create trigger trg_app_perms_touch before update on public.app_perms
  for each row execute function public.touch_updated_at();

-- Siège : le compte admin est admin plateforme.
insert into public.app_perms(email, can_create_projects, is_platform_admin)
  values ('admin@squadbuilder.app', true, true)
  on conflict (email) do update set is_platform_admin = true;

-- ENFORCEMENT : création de projet refusée si can_create_projects = false.
-- (Absence de ligne = autorisé : les comptes existants ne changent pas.)
drop policy if exists org_insert on public.organizations;
create policy org_insert on public.organizations
  for insert with check (
    lower(owner_email) = public.current_email()
    and coalesce(
      (select can_create_projects from public.app_perms
        where lower(email) = public.current_email()),
      true)
  );
