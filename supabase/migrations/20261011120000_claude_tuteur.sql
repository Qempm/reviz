-- Claude dans Reviz, et le tuteur de maîtrise (11 octobre 2026).
--
-- 1. `ai_usage.user_id` : le coût de l'IA par étudiant. Le tuteur est une
--    conversation, pas un job : sans l'étudiant, son coût serait anonyme.
-- 2. La raison d'XP `mastery_check` : 30 XP pour un chapitre jugé maîtrisé.
-- 3. Les sessions du tuteur et leurs messages.
--
-- Arbitrage du propriétaire : **le tuteur est réservé aux packs**, avec **un
-- seul essai gratuit par compte**. La règle vit dans `lib/metier/tuteur.ts` ;
-- la base la garantit aussi, pour qu'une course entre deux requêtes ne donne
-- pas deux essais :
--   - un index unique partiel : une seule session `essai` par étudiant ;
--   - un déclencheur : 20 sessions par jour au plus, même avec un pack, comme
--     les 5 corrections par jour (règle métier 5). C'est une borne de coût.

-- 1. Le coût par étudiant -----------------------------------------------------

alter table public.ai_usage
  add column if not exists user_id uuid references auth.users (id) on delete set null;

create index if not exists ai_usage_user_id_created_at_idx
  on public.ai_usage (user_id, created_at desc);

comment on column public.ai_usage.user_id is
  'L''étudiant à qui l''appel a servi. Nul pour les traitements sans étudiant.';

-- 2. La raison d'XP du tuteur ---------------------------------------------------

alter type public.xp_reason add value if not exists 'mastery_check';

-- 3. Le tuteur ---------------------------------------------------------------

create table public.tuteur_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  chapter_id uuid not null references public.chapters (id) on delete cascade,
  statut text not null default 'en_cours' check (statut in ('en_cours', 'terminee')),
  verdict text check (verdict in ('maitrise', 'a_revoir')),
  score smallint check (score between 0 and 3),
  -- La session gratuite d'un étudiant sans pack actif.
  essai boolean not null default false,
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  -- Une session terminée a son verdict ; une session en cours n'en a pas.
  constraint tuteur_sessions_verdict_si_terminee
    check ((statut = 'terminee') = (verdict is not null))
);

comment on table public.tuteur_sessions is
  'Le tuteur de maîtrise : trois questions ouvertes sur un chapitre, après '
  'une série de QCM. Réservé aux packs, un essai gratuit par compte.';

create index tuteur_sessions_user_created_idx
  on public.tuteur_sessions (user_id, created_at desc);

-- Un seul essai gratuit par compte, garanti par la base.
create unique index tuteur_sessions_un_essai
  on public.tuteur_sessions (user_id)
  where essai;

create table public.tuteur_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.tuteur_sessions (id) on delete cascade,
  role text not null check (role in ('tuteur', 'etudiant')),
  texte text not null check (char_length(texte) between 1 and 2000),
  -- Le jugement d'une réponse : { niveau, retour }. Nul pour les questions.
  evaluation jsonb,
  created_at timestamptz not null default now()
);

create index tuteur_messages_session_idx
  on public.tuteur_messages (session_id, created_at);

-- 20 sessions par jour au plus (UTC, comme les corrections).
create or replace function public.enforce_daily_tuteur_cap()
returns trigger
language plpgsql
as $$
declare
  total integer;
begin
  select count(*) into total
  from public.tuteur_sessions
  where user_id = new.user_id
    and created_at >= date_trunc('day', now());

  if total >= 20 then
    raise exception
      'Plafond atteint : 20 vérifications par jour.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger tuteur_sessions_daily_cap
  before insert on public.tuteur_sessions
  for each row
  execute function public.enforce_daily_tuteur_cap();

revoke all on function public.enforce_daily_tuteur_cap() from public;

-- RLS : l'étudiant lit ses sessions et leurs messages ; seul le serveur
-- (rôle de service) écrit, après avoir vérifié l'accès et appelé le modèle.

alter table public.tuteur_sessions enable row level security;
alter table public.tuteur_messages enable row level security;

create policy "Je lis mes sessions du tuteur"
  on public.tuteur_sessions for select
  to authenticated
  using (user_id = (select auth.uid()));

create policy "Je lis les messages de mes sessions du tuteur"
  on public.tuteur_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.tuteur_sessions s
      where s.id = tuteur_messages.session_id
        and s.user_id = (select auth.uid())
    )
  );
