# Connexion à Supabase

Marche à suivre pour relier le dépôt au projet Supabase hébergé et faire
partir les migrations automatiquement.

> ⚠️ **Ne colle jamais un mot de passe ni une clé de service dans une
> conversation, un fichier versionné ou un ticket.** Tout ce qui est secret va
> soit dans `.env.local` (ignoré par git), soit dans les secrets GitHub, soit
> dans les variables d'environnement Vercel. Les valeurs ci-dessous se
> récupèrent et se collent directement de la console Supabase vers leur
> destination, sans passer par ailleurs.

---

## 1. Créer le projet

Sur [supabase.com/dashboard](https://supabase.com/dashboard) :

| Réglage | Valeur |
| --- | --- |
| Nom | `reviz` |
| Région | **Europe (Frankfurt `eu-central-1` ou Paris `eu-west-3`)** |
| Mot de passe base | généré par la console, **conservé dans ton gestionnaire de mots de passe** |
| Version Postgres | 15 ou plus (le schéma vise 17) |

Pourquoi l'Europe : le trafic Internet béninois transite majoritairement par
l'Europe. Francfort donne 80–150 ms depuis Cotonou, mieux que Le Cap dont le
routage repasse souvent par l'Europe de toute façon. **La région ne se change
plus après création.**

Note la **référence du projet** (`Project Settings → General → Reference ID`),
une chaîne du genre `abcdefghijklmnopqrst`. Elle n'est pas secrète.

---

## 2. Renseigner `.env.local`

À la racine, crée `.env.local` à partir de `.env.example`. Les trois valeurs
Supabase sont dans `Project Settings → API` :

```
NEXT_PUBLIC_SUPABASE_URL=https://<référence>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<clé anon / publishable>
SUPABASE_SERVICE_ROLE_KEY=<clé service_role>
```

`NEXT_PUBLIC_*` part dans le navigateur : c'est voulu, la clé anon ne donne
accès qu'à ce que les politiques RLS autorisent. **`SUPABASE_SERVICE_ROLE_KEY`
contourne toute la RLS** : elle ne doit jamais porter le préfixe
`NEXT_PUBLIC_`, ni apparaître dans un composant client. `lib/supabase/admin.ts`
est marqué `server-only` pour que le build échoue si cela arrivait.

`.env.local` est ignoré par git. Reporte les mêmes valeurs dans Vercel
(`Settings → Environment Variables`) au moment du déploiement.

---

## 3. Appliquer les migrations une première fois

Depuis la racine du dépôt :

```bash
supabase login
npm run db:link -- <référence du projet>
npm run db:push
```

`db:push` demandera le mot de passe de la base. Les onze migrations
s'appliquent dans l'ordre de leur horodatage, seed compris.

> C'est le **premier passage réel du schéma sur une base**. Jusqu'ici il n'a
> été validé que par le parseur Postgres : la syntaxe est sûre, la sémantique
> ne l'est pas encore. Attends-toi à devoir corriger une ou deux choses.

Vérifier ensuite :

```bash
npm run db:types
```

qui écrit `lib/supabase/database.types.ts` à partir du schéma réel. Si ce
fichier se génère, c'est que la base correspond bien au dépôt.

---

## 4. Mises à jour automatiques

Le workflow `.github/workflows/supabase.yml` applique les migrations à chaque
push sur `main` qui touche `supabase/migrations/`. Sur une pull request, il se
contente d'un `--dry-run` : une migration fautive se voit avant la fusion.

### Ce qu'il faut créer sur GitHub

Dépôt → `Settings → Secrets and variables → Actions`.

| Type | Nom | Où le trouver |
| --- | --- | --- |
| **Secret** | `SUPABASE_ACCESS_TOKEN` | [Account → Access Tokens](https://supabase.com/dashboard/account/tokens), « Generate new token » |
| **Secret** | `SUPABASE_DB_PASSWORD` | le mot de passe base choisi à l'étape 1 |
| **Variable** | `SUPABASE_PROJECT_ID` | la référence du projet |

La référence est en *variable* et non en secret : elle n'est pas sensible, et
la garder lisible rend les journaux d'exécution exploitables.

### Ce que le workflow ne fait pas

- **Il n'annule rien.** Supabase applique les migrations en avant seulement.
  Une erreur se corrige par une nouvelle migration, jamais en modifiant une
  migration déjà appliquée — le dépôt et la base divergeraient.
- **Il ne sauvegarde pas avant d'appliquer.** Sur le plan gratuit, prends une
  sauvegarde manuelle avant une migration destructrice.
- **Il ne régénère pas `database.types.ts`.** À lancer à la main après un
  changement de schéma, avec `npm run db:types`.

---

## 5. Commandes utiles

| Commande | Effet |
| --- | --- |
| `npm run db:push` | applique les migrations en attente |
| `npm run db:push:dry` | montre ce qui serait appliqué, sans rien faire |
| `npm run db:diff` | écart entre le schéma local et la base liée |
| `npm run db:types` | régénère les types TypeScript depuis le schéma |
| `npm run db:types:check` | régénère et échoue si le fichier a bougé — dérive entre base et dépôt |

`lib/supabase/database.types.ts` est **généré, pas écrit à la main**. Les trois
clients (`client.ts`, `server.ts`, `admin.ts`) sont paramétrés par le type
`Database` qu'il exporte : une table, une colonne ou une valeur d'énumération
inexistante devient une erreur de compilation. À régénérer après tout
changement de schéma, sinon le code compile contre une base qui n'existe plus.

---

## 6. Activer les méthodes de connexion

Décision du 9 septembre 2026 : connexion par **Google** ou par **code à
6 chiffres envoyé par email**. L'OTP téléphone est abandonné ; le numéro reste
une donnée de profil facultative.

### État constaté sur le projet

| Fournisseur | État | Action |
| --- | --- | --- |
| `email` | actif | vérifier le gabarit, voir ci-dessous |
| `google` | **désactivé** | à configurer |

### Google

1. **Google Cloud Console** → `APIs & Services → Credentials` → *Create OAuth
   client ID*, type **Web application**.
2. Dans *Authorized redirect URIs*, mettre l'URL de rappel Supabase :
   `https://<référence>.supabase.co/auth/v1/callback`.
3. Reporter *Client ID* et *Client Secret* dans Supabase,
   `Authentication → Sign In / Providers → Google`.
4. Dans `Authentication → URL Configuration`, ajouter aux *Redirect URLs* :
   `http://localhost:3000/auth/rappel` et l'URL Vercel une fois déployé.

L'application redirige vers `/auth/rappel`, qui échange le code contre une
session puis oriente vers `/inscription` si le profil n'existe pas encore.

### Email : le gabarit décide de ce que reçoit l'étudiant

⚠️ **Constaté en test le 9 septembre 2026.** Le gabarit *Magic Link* livré par
défaut ne contient que `{{ .ConfirmationURL }}`. L'étudiant reçoit un message
en anglais, « Your sign-in link », avec un lien et **aucun code** — alors que
l'écran de connexion attend six chiffres. Il n'a rien à saisir.

Coller le contenu de **`docs/email-code-connexion.html`** dans
`Authentication → Email Templates → Magic Link`, et mettre « Ton code Reviz »
en objet. Ce gabarit est en français, aux couleurs de l'application, et porte
les deux chemins : le code `{{ .Token }}` en gros, et le lien
`{{ .ConfirmationURL }}` en bas pour qui préfère cliquer.

L'application accepte les deux. `signInWithOtp` déclare `emailRedirectTo` vers
`/auth/rappel`, la même route que le retour Google : un clic sur le lien
échange le code contre une session exactement comme la saisie manuelle.

Pour que le lien aboutisse, l'URL doit figurer dans
`Authentication → URL Configuration → Redirect URLs`, au même titre que celle
de Google.

### Le service d'email intégré ne tient pas en production

Le SMTP fourni par Supabase est **fortement limité** (quelques messages par
heure) et explicitement réservé aux tests. Dès les premiers étudiants, il faut
un SMTP dédié — Resend, SendGrid, Brevo — dans
`Project Settings → Authentication → SMTP Settings`. Sans cela, les codes
cesseront de partir sans prévenir, et l'inscription se bloquera en silence.

> À noter : Supabase refuse les adresses de domaines de test comme
> `example.com`. Pour un essai, utiliser une adresse réellement délivrable.

---

## 7. Ce qui reste à décider

- **Dimension des embeddings.** `chapters.embedding` est en `vector(1024)`,
  d'après Qwen `text-embedding-v3`, seul fournisseur d'embeddings de la pile.
  `docs/STACK-IA.md` ne tranche pas. Changer la dimension impose de recréer la
  colonne : autant le décider avant d'ingérer des cours.
- **Classement.** La RLS interdit de lire le profil d'autrui, alors que l'écran
  Ligue affiche les autres étudiants. Il faudra une fonction `SECURITY DEFINER`
  exposant un classement anonymisé par faculté.
- **Sauvegardes.** Le plan gratuit conserve peu d'historique. À revoir avant
  d'accepter de vrais paiements.
