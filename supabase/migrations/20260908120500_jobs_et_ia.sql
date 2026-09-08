-- File de traitement et consommation des fournisseurs IA.
--
-- Ces deux tables sont invisibles du client : ni lecture ni écriture. Elles
-- sont manipulées par /api/jobs/run, déclenché par Vercel Cron.

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  type public.job_type not null,
  payload jsonb not null default '{}'::jsonb,
  status public.job_status not null default 'queued',
  attempts smallint not null default 0 check (attempts >= 0),
  last_error text,
  run_after timestamptz not null default now(),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

comment on column public.jobs.run_after is
  'Ne pas exécuter avant cette date. Sert aux réessais différés et au report '
  'des traitements lourds hors des heures pleines DeepSeek '
  '(CLAUDE.md, règle métier 6).';

-- Sélection du prochain job exécutable.
create index jobs_a_traiter_idx
  on public.jobs (run_after)
  where status = 'queued';

create index jobs_type_status_idx on public.jobs (type, status);

-- Un ingest_course ne s'exécute pas entre 01:00-04:00 et 06:00-10:00 UTC du
-- lundi au vendredi, sauf s'il attend depuis plus de 20 minutes
-- (CLAUDE.md, règle métier 6). La fonction est utilisée par /api/jobs/run
-- pour filtrer la file ; elle est ici pour que la règle vive avec le schéma.
create or replace function public.job_peut_demarrer(
  job_type public.job_type,
  created timestamptz,
  at_time timestamptz default now()
)
returns boolean
language sql
stable
as $$
  select case
    when job_type <> 'ingest_course' then true
    -- Au-delà de 20 minutes d'attente, on passe outre.
    when at_time - created > interval '20 minutes' then true
    -- Samedi (6) et dimanche (0) : aucune restriction.
    when extract(dow from at_time at time zone 'UTC') in (0, 6) then true
    when extract(hour from at_time at time zone 'UTC') between 1 and 3 then false
    when extract(hour from at_time at time zone 'UTC') between 6 and 9 then false
    else true
  end;
$$;

comment on function public.job_peut_demarrer is
  'Heures pleines DeepSeek : 01:00-04:00 et 06:00-10:00 UTC en semaine. '
  'Les bornes hautes sont exclues (un job à 03:59 attend, à 04:00 il passe).';

-- Consommation IA -----------------------------------------------------------

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs (id) on delete set null,
  provider text not null,
  model text not null,
  prompt_tokens integer not null default 0 check (prompt_tokens >= 0),
  completion_tokens integer not null default 0 check (completion_tokens >= 0),
  cache_hit_tokens integer not null default 0 check (cache_hit_tokens >= 0),
  cost_usd_estimate numeric(10, 6) not null default 0 check (cost_usd_estimate >= 0),
  created_at timestamptz not null default now()
);

create index ai_usage_created_at_idx on public.ai_usage (created_at desc);
create index ai_usage_job_id_idx on public.ai_usage (job_id);
create index ai_usage_provider_model_idx on public.ai_usage (provider, model);
