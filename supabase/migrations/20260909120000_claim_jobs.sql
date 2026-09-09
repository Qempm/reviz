-- Prise de jobs par la file, sans double traitement.
--
-- Vercel Cron déclenche /api/jobs/run toutes les minutes. Deux invocations
-- peuvent se chevaucher si l'une traîne : sans verrou, le même job partirait
-- deux fois et serait facturé deux fois chez le fournisseur IA.
--
-- `for update skip locked` règle le problème dans la base plutôt que dans
-- l'application : chaque appel prend un lot distinct, les lignes déjà
-- verrouillées par un autre appel sont ignorées au lieu de le faire attendre.

-- Reprise des jobs abandonnés : une fonction serverless peut être tuée en
-- plein traitement, laissant la ligne en 'running' pour toujours.
create index jobs_running_idx
  on public.jobs (started_at)
  where status = 'running';

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
        -- En attente et l'heure est venue.
        (c.status = 'queued' and c.run_after <= now())
        -- Ou parti depuis trop longtemps : le traitement a été interrompu.
        or (c.status = 'running' and c.started_at < now() - stale_after)
      )
      -- Heures pleines DeepSeek pour les traitements lourds (règle métier 6).
      and public.job_peut_demarrer(c.type, c.created_at, now())
    order by c.run_after
    limit batch_size
    for update skip locked
  )
  returning j.*;
end;
$$;

comment on function public.claim_jobs is
  'Prend un lot de jobs exécutables et les passe en running en incrémentant '
  'attempts. Les jobs restés en running au-delà de stale_after sont repris : '
  'c''est la seule protection contre une fonction serverless interrompue.';

-- La file est fermée au client : seul le rôle de service peut y puiser.
revoke all on function public.claim_jobs(integer, interval) from public;
revoke all on function public.claim_jobs(integer, interval) from anon;
revoke all on function public.claim_jobs(integer, interval) from authenticated;
grant execute on function public.claim_jobs(integer, interval) to service_role;
