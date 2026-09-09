-- Retire réellement l'accès public aux fonctions du schéma.
--
-- La migration précédente écrivait `revoke ... from anon` sur plusieurs
-- fonctions. Sans effet : Postgres accorde EXECUTE au pseudo-rôle PUBLIC à la
-- création, et révoquer d'un rôle nommé ne retire pas le droit hérité de
-- PUBLIC. Vérifié sur la base : `generate_referral_code` répondait encore 200
-- à un appel anonyme après cette révocation.
--
-- La forme correcte est toujours : révoquer de PUBLIC, puis accorder
-- explicitement aux rôles qui en ont besoin.

-- Tout fermer -------------------------------------------------------------

revoke all on function public.wallet_balance() from public;
revoke all on function public.streak_week(date) from public;
revoke all on function public.current_faculty_id() from public;
revoke all on function public.can_read_course(uuid) from public;
revoke all on function public.generate_referral_code() from public;
revoke all on function public.daily_goal() from public;
revoke all on function public.refresh_streak(uuid) from public;
revoke all on function public.recompute_xp_total(uuid) from public;
revoke all on function public.claim_jobs(integer, interval) from public;
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)
  from public;

-- Rouvrir au strict nécessaire ---------------------------------------------

-- Lues par l'étudiant connecté, sur ses propres données : ces deux fonctions
-- filtrent sur auth.uid() et n'acceptent aucune cible.
grant execute on function public.wallet_balance() to authenticated;
grant execute on function public.streak_week(date) to authenticated;

-- Évaluées à l'intérieur des politiques RLS, donc avec les droits de
-- l'appelant : les fermer casserait la lecture des cours partagés.
grant execute on function public.current_faculty_id() to authenticated;
grant execute on function public.can_read_course(uuid) to authenticated;

-- Valeur par défaut de profiles.referral_code, évaluée à l'INSERT du profil
-- par l'étudiant lui-même.
grant execute on function public.generate_referral_code() to authenticated;

-- Objectif quotidien : une constante, lue par l'interface pour annoncer le
-- seuil de validation d'un jour.
grant execute on function public.daily_goal() to authenticated;

-- Le reste — écritures de compteurs, prise de jobs, planification — n'est
-- appelé que par les triggers (SECURITY DEFINER, donc via le propriétaire)
-- et par le rôle de service.
grant execute on function public.refresh_streak(uuid) to service_role;
grant execute on function public.recompute_xp_total(uuid) to service_role;
grant execute on function public.claim_jobs(integer, interval) to service_role;
grant execute on function public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)
  to service_role;
