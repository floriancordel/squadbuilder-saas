# SquadBuilder — brief de reprise (handoff Claude Code)

> Ce fichier est le point d'entrée pour reprendre le projet exactement où il en est.
> Lis-le en entier avant de coder. L'UI et les commentaires sont en français.

## 1. Ce qu'est le projet

SquadBuilder est un **éditeur visuel d'organigramme produit / R&D**. On construit
l'organisation entièrement à la souris : duo de direction, tribus, squads, cellules
transverses. Aujourd'hui c'est une **appli statique mono‑fichier** (`index.html`) qui
persiste dans le `localStorage` du navigateur.

**Objectif de cette phase :** passer en **SaaS hébergé multi‑comptes** (équipe avec login,
données partagées dans le cloud) sur **Supabase (Postgres + Auth)** + **Vercel (hébergement
statique)**. Le schéma SQL est déjà écrit (`supabase/schema.sql`). Il reste à brancher le
frontend sur Supabase (auth + chargement/sauvegarde), ajouter le partage d'équipe, puis
déployer.

## 2. État actuel (fonctionnel, testé)

`index.html` est une copie fidèle de l'outil final. Tout marche en local. Fonctionnalités :

- **Bloc Direction** (duo CPO / CTO) tout en haut.
- **Tribus** : duo Head of Product + Engineering Manager, rattachées à la Direction.
- **Squads** sous une tribu : bloc « bucket » avec un duo Product Manager / Tech Lead
  **optionnel** + des membres (R&D).
- **Support Cells** sous une tribu : ressources transverses (QA, archi, design, data…)
  avec un **% d'allocation** par personne. Elles sont des **enfants de la tribu dans le flux**
  (sœurs des squads), jamais en position absolue (voir §6, piège overlap).
- **Squads volantes** : squads rattachées **directement à la Direction** (hors tribu),
  badge « Volante », duo PM/Tech Lead optionnel.
- **Hiérarchie d'ajout stricte** : Direction → Tribu / Squad(volante) / Support Cell ;
  Tribu → Squad / Support Cell ; Squad et Support Cell = **terminaux** (on n'ajoute rien
  dessous). La barre d'ajout n'apparaît qu'au survol de la Direction et des Tribus.
- **Plier / déplier** : bouton rond persistant sous chaque bloc (Direction, Tribu, Squad,
  Support Cell). Quand c'est replié, un badge indique le nombre de blocs cachés.
- **Édition dans un volet droit** : clic sur une carte / un en‑tête → panneau. La
  **suppression** (bloc ou personne) se fait uniquement dans ce volet, jamais sur le chart.
- **Distinction visuelle par type** : Direction (violet, bordure épaisse), Tribu (ardoise,
  dégradé), Squad (bordure supérieure indigo + en‑tête indigo), Support Cell (teal, pointillés).
- **Navigation** : zoom molette + déplacement souris, bouton Ajuster.
- **Utilitaires** : Import / Export JSON, Imprimer (PDF), Réinitialiser.

## 3. Modèle de données (objet `state`)

C'est ce qui est stocké (aujourd'hui en `localStorage`, demain dans la colonne `data` jsonb
de la table `organizations`).

```js
state = {
  direction: {
    product: Person,   // role "CPO",  side "produit"
    tech:    Person    // role "CTO",  side "tech"
  },
  heads: [             // les TRIBUS
    {
      id: string,
      product: Person, // role "Head of Product",       side "produit"
      tech:    Person, // role "Engineering Manager",   side "tech"
      squads:  [Squad],
      cells:   [Cell]  // Support Cells
    }
  ],
  squads: [Squad]      // SQUADS VOLANTES rattachées à la Direction
}

Person = {
  pid:    string,                     // id unique de la personne (pas juste du poste)
  role:   string,                     // intitulé de poste
  side:   "produit" | "tech",         // filière (couleur d'accent)
  name:   string,                     // vide = poste ouvert
  loc:    "" | "FR" | "Maroc",        // Hub (FR) / COE (Maroc)
  status: "Occupé" | "Ouvert" | "Recrutement",
  alloc?: number                      // 0..100, présent uniquement pour les ressources de Support Cell
}

Squad = {
  id:   string,
  name: string,
  desc: string,
  pm:   Person | null,   // "Product Manager" — OPTIONNEL (duo optionnel)
  lead: Person | null,   // "Tech Lead"       — OPTIONNEL
  members: [Person]      // membres R&D / mercenaires
}

Cell = {                 // Support Cell
  id: string,
  name: string,
  members: [Person]      // chaque membre a un champ alloc (%)
}
```

`collapsed` est un `Set` d'ids repliés (`"DIR"`, `head.id`, `squad.id`, `cell.id`).

## 4. Fonctions clés dans `index.html`

Tout est dans le `<script>` en bas du fichier (vanilla JS, pas de framework).

- `seed()` / `blank()` : état de démo / état vide. `migrate()` : compat ascendante.
- **Persistance (à remplacer par Supabase) :** `save()` (écrit le `localStorage`),
  `load()` (lit le `localStorage` ou `seed()`), `commit()` = `save()` + `render()`.
- `render()` : reconstruit tout le DOM du chart depuis `state`, puis `updateStats()` et
  `fitIfNeeded()`. Le rendu est intégral à chaque changement (simple et suffisant à cette échelle).
- Rendu par bloc : `headHTML(h)`, `squadHTML(sq, flying)`, `cellHTML(c)`, `duoHTML(a,b)`,
  `cardHTML(p)`, `miniHTML(p)`, `resourceMiniHTML(p)`, `addToolsHTML(ctxHead, showTribu, always)`.
- Édition : `openEditor(obj, kind)` avec `kind` ∈ `"person" | "squad" | "cell" | "tribe"`.
  Panneau à droite (`#editor`). La suppression vit ici (`edDelSquad`, `edDelTribe`,
  `edDelCell`, `edDel` pour une personne).
- Création : `openSquadCreator(preHeadId)` + `createSquad()` (gère rattachement Direction
  `"__dir__"` / tribu / nouvelle tribu `"__new__"`, et la case « inclure le duo »).
  `openCellCreator(headId)` + `createCell()` (sélecteur de tribu, ressources + alloc).
- Helpers : `findSquad`, `findHeadOfSquad`, `findCell`, `findHeadOfCell`, `findMemberCtx`,
  `findCellCtx`, `moveSquad(sqId, target)`, `deleteSquad(id)`, `binomeLabel`, `headLabel`.
- Interaction : délégation de clic sur `#canvas` via `data-action` (`edit`, `edit-squad`,
  `edit-tribe`, `edit-cell`, `toggle`, `add-head`, `add-squad`, `add-cell`, `add-member`,
  `add-res`). Zoom/pan sur `#viewport` (transform sur `#canvas`).

## 5. Cible SaaS — architecture

Garder le frontend **statique** (pas de build) pour rester simple à héberger :

- `index.html` charge le client Supabase depuis le CDN :
  `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`
  puis `const sb = supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY)`.
- `config.js` (non versionné) contient l'URL du projet Supabase et la **clé anon** (publique,
  sans danger — la sécurité vient des policies RLS). Voir `config.example.js`.
- **Auth** : email + mot de passe (Supabase Auth). Écran de login qui masque l'appli tant
  qu'il n'y a pas de session ; à la connexion, on charge l'org de l'utilisateur.
- **Données** : 1 organisation = 1 org chart = 1 ligne dans `organizations`, l'objet `state`
  entier dans la colonne `data` (jsonb). Voir `supabase/schema.sql`.
- **Équipe / partage** : table `memberships` **par email**. Le owner ajoute un email → quand
  cette personne se connecte avec cet email, la RLS lui donne accès. Pas besoin d'API admin.
- **Hébergement** : Vercel en site statique (aucune commande de build, on sert le dossier).

## 6. Décisions de design & pièges (à ne pas refaire)

Ces points ont coûté du temps, respecte‑les :

1. **Support Cells dans le flux, jamais en `position: absolute`.** Une version antérieure les
   plaçait en absolu sur les côtés de la tribu → elles ne réservaient pas d'espace et se
   **superposaient** aux blocs voisins. Elles sont désormais de vrais `<li>` enfants de la tribu.
2. **Connecteurs de l'arbre en CSS pur = fragiles.** Le piège classique : un enfant unique est
   à la fois `:only-child` ET `:last-child`, et la règle `last-child` effaçait la bordure de la
   ligne verticale → squad « déconnectée ». Corrigé en plaçant les règles `:only-child` **après**
   celles `:first/last-child`. **Si tu ajoutes de la complexité de layout, envisage de dessiner
   les connecteurs en SVG** (bien plus robuste que les pseudo‑éléments CSS).
3. **Barres d'action au survol : elles doivent chevaucher le bord du bloc** (contiguës), sinon
   il y a un « trou » et la barre disparaît avant qu'on puisse cliquer.
4. **Le bouton plier/déplier ne fait QUE ça.** L'ajout et la suppression sont ailleurs
   (barre d'ajout au survol pour l'ajout ; volet droit pour la suppression).
5. **Suppression seulement dans le volet droit**, jamais de corbeille sur le chart.
6. **Hiérarchie stricte** (voir §2). Ne pas proposer d'ajouter une tribu sous une squad, etc.

## 7. TODO pour finir le SaaS (ordre conseillé)

1. Ajouter `config.js` (copié de `config.example.js`) + le `<script>` supabase-js dans `index.html`.
2. Écrire une petite **couche data** : `getMyOrg()` (select la 1re org accessible, sinon en créer
   une avec `owner_email = user.email` et `data = seed()`), `saveOrg(state)` (update `data`),
   avec **autosave débouncé** (~800 ms) branché dans `commit()`.
3. **Écran de login** : formulaire email/mot de passe (`sb.auth.signInWithPassword`,
   `sb.auth.signUp`), gestion de session (`sb.auth.getSession`, `onAuthStateChange`),
   bouton **Déconnexion**. Masquer `#viewport`/header tant que pas connecté.
4. Remplacer `load()`/`save()` par la couche Supabase. Garder `render()` inchangé.
5. **Modale « Partager »** : lister les `memberships` de l'org, ajouter un email + rôle
   (`editor`/`viewer`), retirer un membre (owner uniquement). En `viewer`, passer l'UI en
   lecture seule (masquer barres d'ajout, fold OK, pas d'édition).
6. (Option) **Sélecteur d'organisation** si un user appartient à plusieurs orgs.
7. (Option) **Temps réel** : `sb.channel(...).on('postgres_changes', ...)` sur la ligne org
   pour du collaboratif live. Attention au « dernier qui écrit gagne » sur `data` — pour du
   multi‑éditeur simultané, prévoir un merge ou un verrou plus tard.
8. Tester en local (`python3 -m http.server` ou l'extension Live Server) avec un vrai projet
   Supabase, puis déployer (voir README.md).

## 8. Déploiement (résumé — détail dans README.md)

**Supabase :** créer un projet → SQL Editor → coller `supabase/schema.sql` → Run →
Authentication garder Email activé → Settings > API → copier `Project URL` + `anon public key`
→ les mettre dans `config.js`.

**Vercel :** pousser le dossier sur un repo git → Import dans Vercel, preset « Other » (statique,
pas de build) → Deploy. Ou en CLI : `npm i -g vercel` puis `vercel` dans le dossier.

## 9. Fichiers du dépôt

- `index.html` — l'appli complète actuelle (localStorage). C'est la base à faire évoluer.
- `supabase/schema.sql` — tables `organizations` + `memberships`, RLS multi‑comptes, triggers. Prêt.
- `config.example.js` — modèle de config à copier en `config.js` (tes clés Supabase).
- `vercel.json` — config d'hébergement statique.
- `README.md` — guide de déploiement pas à pas (humain).
- `.gitignore` — ignore `config.js` (ne jamais committer tes clés).

## 10. Contraintes / préférences

- UI et libellés en **français**.
- Rester **sans framework ni build** tant que possible (frontend statique).
- La **clé anon** Supabase est publique (OK dans `config.js`). Ne **jamais** exposer la clé
  `service_role`.
- Réponses et itérations : concises et directes.
