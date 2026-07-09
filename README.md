# SquadBuilder

Éditeur visuel d'organigramme produit / R&D. Version en cours de passage en SaaS hébergé
(Supabase + Vercel, multi‑comptes).

> Pour reprendre le projet dans Claude Code : ouvre ce dossier, Claude Code lira
> **CLAUDE.md** automatiquement (contexte complet, modèle de données, TODO, pièges).

## Lancer en local (état actuel)

L'appli actuelle (`index.html`) marche seule, sans dépendances, en `localStorage` :

```bash
python3 -m http.server 8000
# puis ouvrir http://localhost:8000
```

## Déploiement SaaS — pas à pas

### 1. Supabase (base de données + authentification)

1. Crée un compte sur https://supabase.com puis un **nouveau projet** (choisis une région
   proche, note le mot de passe de la base).
2. Ouvre **SQL Editor** > *New query*, colle tout le contenu de `supabase/schema.sql`,
   clique **Run**. (Crée les tables `organizations` et `memberships` + les policies RLS.)
3. **Authentication** : l'option *Email* est active par défaut. Pour tester vite, tu peux
   désactiver la confirmation d'email (*Authentication > Providers > Email > Confirm email*
   → off). À réactiver en production.
4. **Project Settings > API** : copie **Project URL** et la clé **anon public**.

### 2. Configurer l'appli

```bash
cp config.example.js config.js
# édite config.js et colle ton Project URL + ta clé anon
```

`config.js` est ignoré par git (voir `.gitignore`) : tes clés ne partent pas dans le dépôt.
La clé *anon* est publique de toute façon ; c'est la RLS qui protège les données.

### 3. Vercel (hébergement)

**Option A — interface web :** pousse ce dossier sur un dépôt GitHub, puis sur
https://vercel.com fais *Add New > Project > Import*. Preset **Other**, aucune commande de
build (site statique). Deploy.

**Option B — CLI :**
```bash
npm i -g vercel
vercel        # première fois : suit les questions (projet statique)
vercel --prod # met en production
```

> Comme `config.js` n'est pas versionné, si tu déploies via GitHub, ajoute tes deux valeurs
> autrement : soit tu committes un `config.js` (clé anon publique = acceptable), soit tu
> génères `config.js` au build. Le plus simple pour démarrer : committer `config.js`.

## Structure

```
squadbuilder-saas/
├── index.html            # l'appli (à brancher sur Supabase — voir CLAUDE.md §7)
├── config.example.js     # modèle de config (copier en config.js)
├── vercel.json           # hébergement statique
├── .gitignore
├── CLAUDE.md             # brief complet pour reprendre le dev
├── README.md
└── supabase/
    └── schema.sql        # schéma Postgres + RLS (à exécuter dans Supabase)
```

## État du chantier

- [x] Appli complète fonctionnelle (local, `localStorage`)
- [x] Schéma Supabase + RLS multi‑comptes
- [ ] Auth (login / signup / logout) dans le frontend
- [ ] Chargement + sauvegarde de l'org dans Supabase (autosave)
- [ ] Partage d'équipe par email (modale)
- [ ] Déploiement Vercel

Détail et ordre conseillé : **CLAUDE.md §7**.
