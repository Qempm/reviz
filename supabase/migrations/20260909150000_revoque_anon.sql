-- Retire le droit accordé nominativement au rôle `anon`.
--
-- Troisième et dernière passe sur le même sujet. L'explication complète :
-- Supabase pose des privilèges par défaut sur le schéma public qui accordent
-- EXECUTE à `anon`, `authenticated` et `service_role` sur toute fonction
-- créée. Ce droit est **nominatif**, il ne vient pas de PUBLIC — révoquer de
-- PUBLIC (migration précédente) ne le retire donc pas.
--
-- Vérifié sur la base : wallet_balance() et streak_week() répondaient encore
-- 200 à un appel anonyme après la révocation de PUBLIC, parce qu'elles
-- avaient été recréées et avaient hérité du droit nominatif `anon`.
--
-- Règle à suivre pour toute nouvelle fonction : révoquer de PUBLIC ET de
-- anon, puis accorder explicitement.

revoke all on function public.wallet_balance() from anon;
revoke all on function public.streak_week(date) from anon;

-- Les autres ont déjà été fermées à anon, on le redit pour que l'état voulu
-- se lise dans un seul fichier plutôt qu'éparpillé sur trois migrations.
revoke all on function public.current_faculty_id() from anon;
revoke all on function public.can_read_course(uuid) from anon;
revoke all on function public.generate_referral_code() from anon;
revoke all on function public.daily_goal() from anon;
revoke all on function public.refresh_streak(uuid) from anon;
revoke all on function public.recompute_xp_total(uuid) from anon;
revoke all on function public.claim_jobs(integer, interval) from anon;
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)
  from anon;

-- Écritures de compteurs et file : fermées aussi à `authenticated`.
revoke all on function public.refresh_streak(uuid) from authenticated;
revoke all on function public.recompute_xp_total(uuid) from authenticated;
revoke all on function public.claim_jobs(integer, interval) from authenticated;
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)
  from authenticated;
