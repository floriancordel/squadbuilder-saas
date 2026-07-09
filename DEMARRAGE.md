# Démarrer avec Claude Code — mode d'emploi

## A. Ce que tu dois FAIRE (sur ton ordinateur)

1. **Mettre ce dossier où tu veux travailler.** Copie le dossier `squadbuilder-saas`
   dans ton répertoire de projets (par ex. `~/Projets/squadbuilder-saas`).

2. **Ouvrir un terminal dans ce dossier.**
   - Mac : clic droit sur le dossier > « Nouveau terminal au dossier », ou dans Terminal :
     `cd ~/Projets/squadbuilder-saas`

3. **(Recommandé) initialiser git** pour versionner :
   ```bash
   git init && git add . && git commit -m "SquadBuilder — base + schéma Supabase"
   ```

4. **Installer Claude Code** si ce n'est pas déjà fait (voir https://code.claude.com/docs),
   puis le lancer **dans ce dossier** :
   ```bash
   claude
   ```

5. **Créer les 2 comptes gratuits** quand Claude Code te le demandera (il te guidera) :
   - Supabase : https://supabase.com
   - Vercel : https://vercel.com

C'est tout côté « actions ». Claude Code fait le reste (code, tests en local, déploiement).

---

## B. Ce que tu dois DIRE à Claude Code (copier-coller)

Une fois `claude` lancé dans le dossier, colle exactement ce message :

> Lis d'abord le fichier `CLAUDE.md` à la racine : c'est le brief complet du projet.
> On reprend un éditeur d'organigramme produit/R&D (`index.html`, aujourd'hui persistant en
> localStorage) et on le passe en **SaaS hébergé multi‑comptes** avec **Supabase + Vercel**.
> Le schéma SQL est déjà écrit dans `supabase/schema.sql`.
>
> Attaque le **§7 (TODO)** dans l'ordre. Commence par : (1) me guider pour créer le projet
> Supabase et exécuter `supabase/schema.sql`, (2) récupérer mon URL + clé anon et créer
> `config.js`, (3) brancher l'authentification (login / signup / logout), (4) charger et
> sauvegarder l'organisation dans Supabase avec un autosave. Fais‑moi tester en local à
> chaque étape et explique simplement.
>
> Contraintes : ne casse pas l'UI ni la logique décrites dans `CLAUDE.md`, respecte les
> « pièges » du §6, garde le frontend statique sans framework, UI en français.

---

## C. Ensuite (quand l'appli marche en local)

Dis simplement à Claude Code :

> Ajoute la modale « Partager » (inviter un membre par email, rôle editor/viewer), puis
> déploie sur Vercel en me guidant.

Et pour toute évolution future, tu peux repartir de :

> Relis `CLAUDE.md`, puis + ta demande.
