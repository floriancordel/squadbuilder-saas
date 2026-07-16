-- ============================================================
--  fix : INSERT ... RETURNING sur organizations échouait (42501)
--  La policy SELECT has_org_access(id) est appliquée aux lignes du RETURNING ;
--  sa sous-requête (security definer) ne voit pas la ligne en cours d'insertion.
--  → ajout d'un test INLINE owner_email = current_email(), évalué sur la ligne
--  elle-même (aucune visibilité élargie : has_org_access couvrait déjà le owner).
-- ============================================================
drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations
  for select using (
    lower(owner_email) = public.current_email()
    or public.has_org_access(id)
  );
