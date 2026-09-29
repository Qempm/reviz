-- Heures pleines : seulement pour les cours en photo (règle métier 6).
--
-- Arbitrage du 29 septembre 2026. La règle retenait tout `ingest_course`
-- entre 01:00-04:00 et 06:00-10:00 UTC en semaine, jusqu'à vingt minutes,
-- pour éviter le tarif plein de DeepSeek. Or lire un PDF ou un Word n'appelle
-- aucun modèle (unpdf, mammoth) : les retenir n'économisait rien et faisait
-- attendre l'étudiant. Seule une photo passe par la vision ; le dépôt la
-- marque désormais d'un `vision: true` dans la charge utile
-- (`lib/metier/cours.ts`), et c'est elle, seule, que le créneau retient.
--
-- Une nouvelle signature, qui lit la charge utile, plutôt que de modifier
-- l'ancienne : `claim_job` et `claim_jobs` sont réécrites pour l'appeler,
-- l'ancienne reste pour ce qui l'appellerait encore. Miroir TS :
-- `lib/ai/peak-hours.ts` (`canStartJob`).

create or replace function public.job_peut_demarrer(
  job_type public.job_type,
  created timestamptz,
  payload jsonb,
  at_time timestamptz default now()
)
returns boolean
language sql
stable
set search_path = public
as $$
  select case
    when job_type <> 'ingest_course' then true
    -- Un document (PDF, Word) : aucun modèle à la lecture, rien à retenir.
    -- Un job sans le champ — créé avant ce marquage — est traité pareil.
    when coalesce((payload ->> 'vision')::boolean, false) = false then true
    -- Au-delà de 20 minutes d'attente, on passe outre.
    when at_time - created > interval '20 minutes' then true
    -- Samedi (6) et dimanche (0) : aucune restriction.
    when extract(dow from at_time at time zone 'UTC') in (0, 6) then true
    when extract(hour from at_time at time zone 'UTC') between 1 and 3 then false
    when extract(hour from at_time at time zone 'UTC') between 6 and 9 then false
    else true
  end;
$$;

comment on function public.job_peut_demarrer(public.job_type, timestamptz, jsonb, timestamptz) is
  'Heures pleines DeepSeek (01:00-04:00 et 06:00-10:00 UTC en semaine), '
  'appliquées à la seule lecture d''un cours en photo (payload.vision). '
  'PDF et Word démarrent à toute heure.';

revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, jsonb, timestamptz) from public;
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, jsonb, timestamptz) from anon;
revoke all on function public.job_peut_demarrer(public.job_type, timestamptz, jsonb, timestamptz) from authenticated;
grant execute on function public.job_peut_demarrer(public.job_type, timestamptz, jsonb, timestamptz) to service_role;

-- La file : même corps qu'avant, seul l'appel au créneau change.
create or replace function public.claim_jobs(
  batch_size integer default 5,
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
  where j.id in (
    select c.id
    from public.jobs c
    where (
        (c.status = 'queued' and c.run_after <= now())
        or (c.status = 'running' and c.started_at < now() - stale_after)
      )
      and public.job_peut_demarrer(c.type, c.created_at, c.payload, now())
    order by c.run_after
    limit batch_size
    for update skip locked
  )
  returning j.*;
end;
$$;

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
      and public.job_peut_demarrer(c.type, c.created_at, c.payload, now())
    for update skip locked
  )
  returning j.*;
end;
$$;

-- `create or replace` garde les droits existants ; on les répète quand même,
-- pour que la migration dise seule qui peut puiser dans la file.
revoke all on function public.claim_jobs(integer, interval) from public, anon, authenticated;
grant execute on function public.claim_jobs(integer, interval) to service_role;
revoke all on function public.claim_job(uuid, interval) from public, anon, authenticated;
grant execute on function public.claim_job(uuid, interval) to service_role;
