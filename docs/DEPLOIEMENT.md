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

---

## Connexion Google en production

Après chaque changement de domaine, ajouter l'URL de retour dans Supabase,
`Authentication → URL Configuration → Redirect URLs` :

```
https://<domaine>/auth/rappel
```

Sans cela, la connexion Google aboutit mais ne dépose pas de session :
l'étudiant revient à l'écran de connexion sans message d'erreur.
