-- Cours importés, contenu généré et suivi de révision.

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  subject_id uuid references public.subjects (id) on delete set null,
  title text not null,
  file_hash text not null,
  storage_path text not null,
  -- Plafond de 150 pages par cours (CLAUDE.md, règle métier 5).
  page_count smallint check (page_count between 0 and 150),
  status public.course_status not null default 'uploaded',
  shared_with_faculty boolean not null default false,
  exam_date date,
  created_at timestamptz not null default now(),

  unique (owner_id, file_hash)
);

comment on column public.courses.file_hash is
  'Empreinte du fichier source. Sert au cache IA : un document déjà traité '
  'par quelqu''un de la même faculté n''est jamais retraité '
  '(CLAUDE.md, règle métier 4).';

create index courses_owner_id_idx on public.courses (owner_id);
create index courses_subject_id_idx on public.courses (subject_id);

-- Recherche du cache IA : retrouver un cours déjà traité pour la même
-- empreinte, restreint aux cours partagés à la faculté.
create index courses_file_hash_ready_idx
  on public.courses (file_hash)
  where status = 'ready';

-- Chapitres -----------------------------------------------------------------

create table public.chapters (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  index smallint not null,
  title text not null,
  text text not null,
  token_count integer check (token_count >= 0),
  -- 1024 dimensions : Qwen text-embedding-v3, le seul fournisseur de la
  -- pile qui expose des embeddings. À revoir si docs/STACK-IA.md tranche
  -- autrement — ce fichier n'existe pas encore.
  embedding extensions.vector(1024),
  created_at timestamptz not null default now(),

  unique (course_id, index)
);

create index chapters_course_id_idx on public.chapters (course_id);

-- Questions -----------------------------------------------------------------

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters (id) on delete cascade,
  type public.question_type not null,
  statement text not null,
  options jsonb,
  answer text not null,
  explanation text,
  probability public.question_probability not null default 'medium',
  created_at timestamptz not null default now(),

  -- Un QCM porte ses propositions, une question ouverte n'en a pas.
  constraint questions_options_coherentes check (
    (type = 'mcq' and jsonb_typeof(options) = 'array')
    or (type = 'open' and options is null)
  )
);

create index questions_chapter_id_idx on public.questions (chapter_id);

-- Plafond de 200 questions générées par cours (CLAUDE.md, règle métier 5).
create or replace function public.enforce_question_cap()
returns trigger
language plpgsql
as $$
declare
  course uuid;
  total integer;
begin
  select c.course_id into course
  from public.chapters c
  where c.id = new.chapter_id;

  select count(*) into total
  from public.questions q
  join public.chapters c on c.id = q.chapter_id
  where c.course_id = course;

  if total >= 200 then
    raise exception
      'Plafond atteint : 200 questions maximum par cours (cours %).', course
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger questions_cap
  before insert on public.questions
  for each row
  execute function public.enforce_question_cap();

-- Fiches --------------------------------------------------------------------

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references public.chapters (id) on delete cascade,
  front text not null,
  back text not null,
  created_at timestamptz not null default now()
);

create index flashcards_chapter_id_idx on public.flashcards (chapter_id);

-- Réponses ------------------------------------------------------------------

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  is_correct boolean not null,
  answered_at timestamptz not null default now()
);

create index attempts_user_id_answered_at_idx
  on public.attempts (user_id, answered_at desc);

create index attempts_question_id_idx on public.attempts (question_id);

-- Plafond de 300 questions répondues par jour et par étudiant
-- (CLAUDE.md, règle métier 5).
create or replace function public.enforce_daily_attempt_cap()
returns trigger
language plpgsql
as $$
declare
  total integer;
begin
  select count(*) into total
  from public.attempts
  where user_id = new.user_id
    and answered_at >= date_trunc('day', now());

  if total >= 300 then
    raise exception
      'Plafond atteint : 300 questions par jour.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger attempts_daily_cap
  before insert on public.attempts
  for each row
  execute function public.enforce_daily_attempt_cap();

-- Corrections de copies -----------------------------------------------------

create table public.corrections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid references public.courses (id) on delete set null,
  storage_paths jsonb not null default '[]'::jsonb,
  status public.correction_status not null default 'pending',
  grade numeric(5, 2) check (grade >= 0),
  max_grade numeric(5, 2) check (max_grade > 0),
  rubric jsonb,
  feedback jsonb,
  model_used text,
  created_at timestamptz not null default now(),

  constraint corrections_note_dans_le_bareme check (
    grade is null or max_grade is null or grade <= max_grade
  )
);

create index corrections_user_id_created_at_idx
  on public.corrections (user_id, created_at desc);

-- Plafond de 5 corrections par jour, y compris en pack illimité
-- (CLAUDE.md, règle métier 5).
create or replace function public.enforce_daily_correction_cap()
returns trigger
language plpgsql
as $$
declare
  total integer;
begin
  select count(*) into total
  from public.corrections
  where user_id = new.user_id
    and created_at >= date_trunc('day', now());

  if total >= 5 then
    raise exception
      'Plafond atteint : 5 corrections par jour.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger corrections_daily_cap
  before insert on public.corrections
  for each row
  execute function public.enforce_daily_correction_cap();
