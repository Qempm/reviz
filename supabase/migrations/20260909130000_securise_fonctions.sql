-- Ferme un contournement de la RLS par les fonctions SECURITY DEFINER.
--
-- Constaté sur la base après le premier déploiement : `wallet_balance` et
-- `streak_week` prenaient un identifiant d'utilisateur en paramètre, étaient
-- SECURITY DEFINER, et restaient appelables en RPC par le rôle `anon`. Or la
-- clé anon est embarquée dans le navigateur. Un appel du genre
--
--   POST /rest/v1/rpc/wallet_balance {"target": "<uuid d'un autre étudiant>"}
--
-- répondait 200 avec son solde, en contournant entièrement les politiques.
--
-- Correction : ces deux fonctions n'acceptent plus de cible et travaillent
-- sur auth.uid(). Le code serveur qui a besoin du solde d'un tiers passe par
-- le rôle de service et somme wallet_ledger directement.

-- Portefeuille --------------------------------------------------------------

drop function if exists public.wallet_balance(uuid);

create or replace function public.wallet_balance()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(amount_fcfa), 0)::integer
  from public.wallet_ledger
  where user_id = auth.uid();
$$;

comment on function public.wallet_balance is
  'Solde de l''étudiant connecté. Sans paramètre, volontairement : une cible '
  'libre sur une fonction SECURITY DEFINER exposée en RPC contournerait la RLS.';

-- Série de révision ---------------------------------------------------------

drop function if exists public.streak_week(uuid, date);

create or replace function public.streak_week(
  anchor date default (now() at time zone 'UTC')::date
)
returns table (
  day date,
  weekday smallint,
  questions_answered smallint,
  xp_earned integer,
  is_validated boolean,
  is_today boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d::date as day,
    extract(isodow from d)::smallint as weekday,
    coalesce(a.questions_answered, 0::smallint) as questions_answered,
    coalesce(a.xp_earned, 0) as xp_earned,
    coalesce(a.is_validated, false) as is_validated,
    d::date = (now() at time zone 'UTC')::date as is_today
  from generate_series(
    date_trunc('week', anchor)::date,
    date_trunc('week', anchor)::date + 6,
    interval '1 day'
  ) as d
  left join public.daily_activity a
    on a.user_id = auth.uid() and a.day = d::date
  order by d;
$$;

comment on function public.streak_week is
  'Les 7 cases de la carte streak pour l''étudiant connecté. Sans paramètre '
  'de cible, pour la même raison que wallet_balance.';

-- Fermeture des fonctions internes -----------------------------------------
--
-- Postgres accorde EXECUTE à PUBLIC par défaut sur toute fonction créée :
-- il faut retirer explicitement ce qui n'a pas à être appelable depuis le
-- navigateur.

-- Écritures déclenchées par les triggers et le rôle de service. Les triggers
-- sont eux-mêmes SECURITY DEFINER : ils gardent l'accès via le propriétaire.
revoke all on function public.refresh_streak(uuid) from public, anon, authenticated;
revoke all on function public.recompute_xp_total(uuid) from public, anon, authenticated;

-- Fonction utilitaire de la file, déjà fermée à sa création. On le redit ici
-- pour que la sécurité de la file tienne dans un seul fichier.
revoke all on function public.claim_jobs(integer, interval) from public, anon, authenticated;

-- Prédicat pur de planification : aucune donnée, mais rien à faire côté client.
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)
  from public, anon, authenticated;

-- `anon` n'a besoin d'aucune de ces fonctions : avant connexion, seules les
-- tables de référence et la boutique sont lisibles.
revoke all on function public.current_faculty_id() from anon;
revoke all on function public.can_read_course(uuid) from anon;
revoke all on function public.generate_referral_code() from anon;
revoke all on function public.daily_goal() from anon;

-- `authenticated` garde ce que la RLS et l'inscription exigent :
--   - current_faculty_id et can_read_course sont évalués dans les politiques,
--     donc avec les droits de l'appelant : les fermer casserait la lecture
--     des cours partagés ;
--   - generate_referral_code est la valeur par défaut de profiles.referral_code
--     et s'évalue à l'INSERT du profil, donc avec les droits de l'étudiant.
grant execute on function public.current_faculty_id() to authenticated;
grant execute on function public.can_read_course(uuid) to authenticated;
grant execute on function public.generate_referral_code() to authenticated;
grant execute on function public.daily_goal() to authenticated;

grant execute on function public.wallet_balance() to authenticated;
grant execute on function public.streak_week(date) to authenticated;
