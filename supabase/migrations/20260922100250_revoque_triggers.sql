-- Retire `authenticated` des deux fonctions de trigger de la phase 0.
--
-- La leçon de 20260909150000_revoque_anon.sql était énoncée pour `anon` :
-- « les privilèges par défaut de Supabase accordent EXECUTE nominativement,
-- ce qui survit à une révocation de PUBLIC ». Elle vaut aussi pour
-- `authenticated`, et 20260922100000 et 20260922100200 ne l'ont révoqué ni
-- pour l'une ni pour l'autre.
--
-- C'est l'assertion de 20260922100300 qui l'a signalé, en refusant le
-- déploiement :
--
--   ERROR: Droits en trop : public.protect_profile_insert() → authenticated,
--          public.force_attempt_timestamp() → authenticated
--
-- Quatrième passe sur le même motif, et cette fois le garde-fou a fait son
-- travail avant la mise en ligne plutôt qu'après.
--
-- Révoquer l'EXECUTE n'empêche pas le trigger de fonctionner : un trigger
-- s'exécute dans le contexte de la table, pas avec les droits du rôle
-- appelant. `refresh_streak(uuid)` en est la preuve depuis le 9 septembre —
-- révoquée de `authenticated` et pourtant appelée par `track_attempt()`.

revoke all on function public.protect_profile_insert() from authenticated;
revoke all on function public.force_attempt_timestamp() from authenticated;

-- Le trigger d'UPDATE, antérieur, n'avait jamais été refermé non plus.
revoke all on function public.protect_profile_columns() from authenticated;
