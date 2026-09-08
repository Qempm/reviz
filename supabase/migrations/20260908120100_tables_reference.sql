-- Données de référence : établissements et catalogue de packs.
--
-- Ces tables sont en lecture publique (politiques dans 20260908120600_rls.sql)
-- et ne sont écrites que par le rôle de service.

create table public.universities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  city text,
  country_code text not null default 'BJ',
  created_at timestamptz not null default now()
);

comment on table public.universities is
  'Universités couvertes. `code` est l''acronyme affiché (UAC, UP…).';

create table public.faculties (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references public.universities (id) on delete cascade,
  code text not null,
  name text not null,
  created_at timestamptz not null default now(),
  unique (university_id, code)
);

create index faculties_university_id_idx on public.faculties (university_id);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  faculty_id uuid not null references public.faculties (id) on delete cascade,
  name text not null,
  study_year smallint check (study_year between 1 and 7),
  created_at timestamptz not null default now(),
  unique (faculty_id, name)
);

create index subjects_faculty_id_idx on public.subjects (faculty_id);

-- Packs ---------------------------------------------------------------------

create table public.packs (
  code public.pack_code primary key,
  label text not null,
  description text,
  price_fcfa integer not null check (price_fcfa >= 0),
  duration_days smallint not null check (duration_days > 0),
  corrections_included smallint not null check (corrections_included >= 0),
  -- NULL = aucune limite de matières.
  subjects_limit smallint check (subjects_limit > 0),
  active_from timestamptz not null default now(),
  active_to timestamptz,
  created_at timestamptz not null default now(),
  check (active_to is null or active_to > active_from)
);

comment on table public.packs is
  'Catalogue des packs. Achat unique, à durée limitée : aucun renouvellement '
  'automatique (CLAUDE.md, règle métier 1).';

comment on column public.packs.subjects_limit is
  'Nombre de matières activables. NULL vaut illimité.';

-- Pack actuellement en vente pour un code donné.
create index packs_active_idx on public.packs (code, active_from, active_to);
