# Déploiement

Projet Vercel `reviz`, connecté au dépôt `github.com/Qempm/reviz`.

## Variables d'environnement

Posées sur Vercel en *Production* et *Preview* :

| Variable | Type | Rôle |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Config | publique, part dans le navigateur |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Config | publique par conception, bornée par la RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | Secret | contourne la RLS, serveur uniquement |
| `CRON_SECRET` | Secret | protège `/api/jobs/run` |

Vercel refuse d'enregistrer une valeur qui ressemble à un secret sous un nom
`NEXT_PUBLIC_` sans `--type config` explicite. C'est un garde-fou utile :
il force à confirmer qu'on veut bien exposer la valeur.

Restent à renseigner quand les fonctionnalités arriveront :
`DEEPSEEK_API_KEY`, `DASHSCOPE_API_KEY`, `ZAI_API_KEY`,
`FEDAPAY_SECRET_KEY`, `FEDAPAY_WEBHOOK_SECRET`, `N8N_WHATSAPP_WEBHOOK_URL`.

---

## La file de jobs ne tourne qu'une fois par jour

⚠️ **Limite du plan Hobby.** Le déploiement échoue avec :

> Hobby accounts are limited to daily cron jobs. This cron expression
> (`* * * * *`) would run more than once per day.

`vercel.json` déclare donc `0 22 * * *` — une fois par jour, à 22:00 UTC,
soit 23 h à Cotonou. L'heure est choisie hors des créneaux chargés de
DeepSeek (01:00–04:00 et 06:00–10:00 UTC, règle métier 6).

**Ce n'est qu'un filet de sécurité, pas la cadence de production.** Un
étudiant qui dépose un cours à 14 h ne peut pas attendre 22 h. Deux sorties :

1. **Déclencheur externe gratuit** — un service comme cron-job.org appelant
   toutes les minutes :

   ```
   GET https://<domaine>/api/jobs/run
   Authorization: Bearer <CRON_SECRET>
   ```

   La route est protégée par comparaison à temps constant et répond
   `{ ok, data }`. Elle est idempotente : `claim_jobs` verrouille les lignes
   prises, deux appels simultanés ne traitent jamais le même job.

2. **Plan Pro Vercel**, qui débloque les crons à la minute.

3. **`pg_cron` + `pg_net` depuis Supabase**, gratuit et inclus. La base
   appelle elle-même la route toutes les minutes :

   ```sql
   select cron.schedule(
     'reviz-file-jobs', '* * * * *',
     $$select net.http_post(
         url := 'https://<domaine>/api/jobs/run',
         headers := jsonb_build_object(
           'Authorization',
           'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
                         where name = 'CRON_SECRET')
         )
       )$$
   );
   ```

   **À faire par le propriétaire, pas par un agent** : la planification a
   besoin de `CRON_SECRET` dans le Vault Supabase
   (`select vault.create_secret('…', 'CRON_SECRET')`), et un secret ne se
   colle ni dans une migration versionnée ni dans une conversation.

### Pourquoi il n'y a pas encore de déclenchement immédiat

Le plan prévoyait `after()` de `next/server` pour lancer la file dans la
foulée du dépôt, afin que la latence perçue soit nulle. Ce n'est pas encore
branché, et pour une raison précise : **aucun des quatre traitements lourds
n'existe** (`ingest_course`, `generate_questions`, `correct_copy`,
`verify_card` attendent les clés IA). Or `lib/jobs/runner.ts` échoue
*définitivement* sur un type sans traitement enregistré — délibérément, un
type orphelin étant un défaut de code. Mettre un job `ingest_course` en file
aujourd'hui le ferait donc passer en `failed` au premier passage du cron,
sans aucun bénéfice.

En attendant, **`courses.status = 'processing'` fait office de file
d'attente** : la reprise se fera d'une requête, sans backfill compliqué.

---

## Connexion Google en production

Après chaque changement de domaine, ajouter l'URL de retour dans Supabase,
`Authentication → URL Configuration → Redirect URLs` :

```
https://<domaine>/auth/rappel
```

Sans cela, la connexion Google aboutit mais ne dépose pas de session :
l'étudiant revient à l'écran de connexion sans message d'erreur.
