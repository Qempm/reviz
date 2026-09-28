-- Corriger une copie tout de suite, et décompter ce qu'elle coûte.
--
-- Deux fonctions, pour deux trous constatés dans le code :
--
--  1. **`claim_jobs()` prend le lot le plus ancien.** Le cron de Vercel ne
--     tourne qu'une fois par jour sur l'offre Hobby (`vercel.json`), alors
--     qu'une copie photographiée à 21:00 avant un contrôle doit être corrigée
--     dans la minute. On veut donc lancer le traitement depuis l'invocation
--     de l'étudiant — mais `claim_jobs(5)` lui ferait traiter les jobs des
--     autres. D'où `claim_job(uuid)` : la même prise, sur une ligne nommée.
--
--  2. **Rien ne décrémente jamais `subscriptions.corrections_left`.** La
--     colonne est lue par `etatAcces()`, écrite à l'achat par
--     `enregistrer_paiement()`, et diminuée nulle part dans tout le dépôt :
--     un pack payé donne aujourd'hui des corrections illimitées, bornées
--     seulement par le trigger `corrections_daily_cap` (5 par jour). La
--     branche `correctionsLeft <= 0` de `peutCorriger()` ne peut pas se
--     déclencher. D'où `consommer_correction(uuid)`.
--
-- Les deux sont réservées au rôle de service : l'une puise dans la file,
-- l'autre touche à un accès payé.

-- Prise d'un job nommé.
--
-- Mêmes conditions que `claim_jobs`, à une ligne près : `queued` dont l'heure
-- est venue, ou `running` abandonné depuis trop longtemps. Le
-- `for update skip locked` est ce qui rend l'exécution immédiate et le cron
-- inoffensifs l'un pour l'autre — le second arrivé ne voit rien à prendre, et
-- repart sans rien faire plutôt que d'attendre.
create or replace function public.claim_job(
  p_id uuid,
  stale_after interval default '10 minutes'
)
returns setof public.jobs
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  update public.jobs j
  set status = 'running',
      attempts = j.attempts + 1,
      started_at = now(),
      finished_at = null
  where j.id = (
    select c.id
    from public.jobs c
    where c.id = p_id
      and (
        (c.status = 'queued' and c.run_after <= now())
        or (c.status = 'running' and c.started_at < now() - stale_after)
      )
      -- Le contrôle des heures pleines s'applique aussi ici : un traitement
      -- lourd ne devient pas léger parce qu'un étudiant attend devant son
      -- écran (règle métier 6). `correct_copy` n'en fait pas partie, donc le
      -- chemin immédiat de la correction est libre.
      and public.job_peut_demarrer(c.type, c.created_at, now())
    for update skip locked
  )
  returning j.*;
end;
$$;

comment on function public.claim_job(uuid, interval) is
  'Prend un job nommé et le passe en running, aux mêmes conditions que '
  'claim_jobs. Rend zéro ligne si le job est déjà pris, pas encore dû, ou '
  'bloqué par les heures pleines — l''appelant n''a alors rien à faire.';

revoke all on function public.claim_job(uuid, interval) from public;
revoke all on function public.claim_job(uuid, interval) from anon;
revoke all on function public.claim_job(uuid, interval) from authenticated;
grant execute on function public.claim_job(uuid, interval) to service_role;

-- Décompte d'une correction.
--
-- Sur quel abonnement ? **Celui qui expire le plus tôt**, parmi les actifs
-- qui ont encore du crédit. Un pack Contrôle de sept jours et un pack
-- Semestre peuvent courir ensemble ; consommer d'abord ce qui périmerait de
-- toute façon est le seul ordre qui ne fasse pas perdre de crédit à
-- l'étudiant.
--
-- Rend le nombre de corrections restantes après décompte, tous packs actifs
-- confondus — c'est la somme que lit `etatAcces()` — ou NULL si aucun
-- abonnement n'a pu être décompté.
create or replace function public.consommer_correction(p_user uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_abonnement uuid;
  v_restant integer;
begin
  select s.id into v_abonnement
  from public.subscriptions s
  where s.user_id = p_user
    and s.starts_at <= now()
    and s.ends_at > now()
    and s.corrections_left > 0
  order by s.ends_at asc
  limit 1
  -- Deux corrections terminées en même temps ne doivent pas décompter la
  -- même unité deux fois.
  for update;

  if not found then
    return null;
  end if;

  update public.subscriptions
  set corrections_left = corrections_left - 1
  where id = v_abonnement;

  select coalesce(sum(s.corrections_left), 0) into v_restant
  from public.subscriptions s
  where s.user_id = p_user
    and s.starts_at <= now()
    and s.ends_at > now();

  return v_restant;
end;
$$;

comment on function public.consommer_correction(uuid) is
  'Retire une correction au pack actif qui expire le plus tôt et rend le '
  'total restant. NULL si aucun pack actif n''a de crédit. Appelée au '
  'succès de la correction, pas au dépôt : facturer une correction que l''IA '
  'n''a pas produite serait facturer du vide, et le plafond de 5 par jour '
  'suffit à empêcher qu''on relance sans fin.';

revoke all on function public.consommer_correction(uuid) from public;
revoke all on function public.consommer_correction(uuid) from anon;
revoke all on function public.consommer_correction(uuid) from authenticated;
grant execute on function public.consommer_correction(uuid) to service_role;
