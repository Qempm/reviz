-- Points d'expérience et séries de révision.
--
-- Les maquettes Stitch reposent sur ces deux notions à chaque écran (badge XP
-- du header, carte « 5 jours de flamme », pilules XP du podium), mais le
-- modèle initial de CLAUDE.md ne les couvrait pas.
--
-- Deux principes repris du reste du schéma :
--   - xp_events est un journal en ajout seul, comme wallet_ledger ;
--   - le total est malgré tout dénormalisé dans profiles, parce que le
--     classement d'une faculté ne peut pas sommer le journal de chaque
--     étudiant à chaque affichage. Le journal reste la source de vérité, la
--     colonne est un cache tenu par trigger.

create type public.xp_reason as enum (
  'correct_answer',
  'quiz_completed',
  'daily_goal',
  'streak_bonus',
  'course_added',
  'correction_done',
  'referral',
  'adjustment'
);

-- Journal des gains ---------------------------------------------------------

create table public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  reason public.xp_reason not null,
  -- Négatif possible uniquement pour un ajustement manuel.
  amount integer not null check (amount <> 0),
  reference_id uuid,
  created_at timestamptz not null default now(),

  constraint xp_events_seul_ajustement_negatif check (
    amount > 0 or reason = 'adjustment'
  )
);

comment on table public.xp_events is
  'Journal des points d''expérience, en ajout seul. Une erreur se corrige par '
  'une ligne de type adjustment, jamais par une modification.';

create index xp_events_user_id_created_at_idx
  on public.xp_events (user_id, created_at desc);

create or replace function public.xp_events_is_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception
    'xp_events est un journal en ajout seul. Pour corriger, insérer une ligne '
    'de type adjustment.'
    using errcode = 'restrict_violation';
end;
$$;

create trigger xp_events_no_update
  before update on public.xp_events
  for each row
  execute function public.xp_events_is_immutable();

create trigger xp_events_no_delete
  before delete on public.xp_events
  for each row
  execute function public.xp_events_is_immutable();

-- Compteurs dénormalisés ----------------------------------------------------

alter table public.profiles
  add column xp_total integer not null default 0,
  add column current_streak smallint not null default 0 check (current_streak >= 0),
  add column longest_streak smallint not null default 0 check (longest_streak >= 0),
  add column last_validated_on date;

comment on column public.profiles.xp_total is
  'Cache de la somme de xp_events, tenu par trigger. Se recalcule avec '
  'public.recompute_xp_total().';

comment on column public.profiles.current_streak is
  'Nombre de jours validés consécutifs, dernier jour validé inclus. Une série '
  'est rompue dès qu''un jour passe sans atteindre l''objectif quotidien.';

-- Classement d'une faculté : ordre décroissant sur le total.
create index profiles_faculty_xp_idx
  on public.profiles (faculty_id, xp_total desc);

-- Activité quotidienne ------------------------------------------------------

create table public.daily_activity (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  questions_answered smallint not null default 0 check (questions_answered >= 0),
  correct_answers smallint not null default 0 check (correct_answers >= 0),
  xp_earned integer not null default 0,
  is_validated boolean not null default false,
  created_at timestamptz not null default now(),

  primary key (user_id, day),
  constraint daily_activity_bonnes_reponses_coherentes
    check (correct_answers <= questions_answered)
);

comment on table public.daily_activity is
  'Un enregistrement par étudiant et par jour. Alimente la carte des 7 jours '
  'et sert de base au calcul des séries.';

create index daily_activity_day_idx on public.daily_activity (day desc);

-- Objectif quotidien --------------------------------------------------------

-- Nombre de questions à répondre dans la journée pour valider le jour et
-- entretenir la série. Isolé dans une fonction pour être ajustable par simple
-- CREATE OR REPLACE, sans migration de schéma.
--
-- 10 est une valeur de départ : assez court pour être atteint dans un
-- transport, assez long pour valoir quelque chose. À confronter aux premiers
-- usages réels.
create or replace function public.daily_goal()
returns smallint
language sql
immutable
as $$
  select 10::smallint;
$$;

-- Entretien des compteurs ---------------------------------------------------

-- Recalcule la série d'un étudiant à partir de son historique de jours
-- validés. Appelée quand un jour bascule à validé.
create or replace function public.refresh_streak(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  dernier date;
  serie smallint := 0;
  curseur date;
begin
  select max(day) into dernier
  from public.daily_activity
  where user_id = target and is_validated;

  if dernier is null then
    update public.profiles
    set current_streak = 0, last_validated_on = null
    where id = target;
    return;
  end if;

  -- Remonte les jours validés consécutifs à partir du dernier.
  curseur := dernier;
  loop
    exit when not exists (
      select 1 from public.daily_activity
      where user_id = target and day = curseur and is_validated
    );
    serie := serie + 1;
    curseur := curseur - 1;
  end loop;

  update public.profiles
  set current_streak = serie,
      longest_streak = greatest(longest_streak, serie),
      last_validated_on = dernier
  where id = target;
end;
$$;

comment on function public.refresh_streak is
  'La série affichée reste celle du dernier jour validé : elle ne se remet pas '
  'à zéro d''elle-même à minuit. C''est à l''affichage de la présenter comme '
  'rompue si last_validated_on est antérieur à hier.';

-- Une réponse alimente le compteur du jour et peut valider la journée.
create or replace function public.track_attempt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jour date := (new.answered_at at time zone 'UTC')::date;
  total_du_jour smallint;
  deja_valide boolean;
begin
  -- RETURNING porte sur la ligne telle qu'elle existe après l'opération :
  -- total_du_jour est donc déjà le compte à jour, sans incrément à ajouter.
  insert into public.daily_activity as d
    (user_id, day, questions_answered, correct_answers)
  values
    (new.user_id, jour, 1, case when new.is_correct then 1 else 0 end)
  on conflict (user_id, day) do update
    set questions_answered = d.questions_answered + 1,
        correct_answers = d.correct_answers
          + case when new.is_correct then 1 else 0 end
  returning d.questions_answered, d.is_validated
    into total_du_jour, deja_valide;

  if not deja_valide and total_du_jour >= public.daily_goal() then
    update public.daily_activity
    set is_validated = true
    where user_id = new.user_id and day = jour;

    perform public.refresh_streak(new.user_id);
  end if;

  return new;
end;
$$;

create trigger attempts_track_activity
  after insert on public.attempts
  for each row
  execute function public.track_attempt();

-- Un gain de XP met à jour le total et le cumul du jour.
create or replace function public.track_xp_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jour date := (new.created_at at time zone 'UTC')::date;
begin
  update public.profiles
  set xp_total = greatest(0, xp_total + new.amount)
  where id = new.user_id;

  -- Dans un ON CONFLICT DO UPDATE, la ligne existante se désigne par l'alias
  -- de la table cible, pas par son nom qualifié.
  insert into public.daily_activity as d (user_id, day, xp_earned)
  values (new.user_id, jour, new.amount)
  on conflict (user_id, day) do update
    set xp_earned = d.xp_earned + excluded.xp_earned;

  return new;
end;
$$;

create trigger xp_events_track
  after insert on public.xp_events
  for each row
  execute function public.track_xp_event();

-- Filet de sécurité : recalcule le total depuis le journal.
create or replace function public.recompute_xp_total(target uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  total integer;
begin
  select coalesce(sum(amount), 0)::integer into total
  from public.xp_events
  where user_id = target;

  update public.profiles set xp_total = greatest(0, total) where id = target;
  return total;
end;
$$;

-- Lecture de la carte 7 jours -----------------------------------------------

-- Renvoie les 7 jours de la semaine contenant `anchor`, du lundi au dimanche,
-- avec l'état attendu par la carte streak (docs/DESIGN.md § 7).
create or replace function public.streak_week(
  target uuid default auth.uid(),
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
-- Volontairement SECURITY INVOKER : la fonction prend un identifiant en
-- paramètre, un SECURITY DEFINER laisserait lire l'activité de n'importe qui.
-- En invoker, la politique de daily_activity s'applique et un identifiant
-- étranger ne renvoie que des jours vides.
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
    on a.user_id = target and a.day = d::date
  order by d;
$$;

comment on function public.streak_week is
  'Les 7 cases de la carte streak, lundi (isodow 1) à dimanche (7). Renvoie '
  'toujours 7 lignes, y compris pour les jours sans activité.';

-- Sécurité ------------------------------------------------------------------

alter table public.xp_events enable row level security;
alter table public.daily_activity enable row level security;

create policy "Je lis mes gains d'XP"
  on public.xp_events for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je lis mon activité quotidienne"
  on public.daily_activity for select
  to authenticated
  using (user_id = auth.uid());

-- Aucune politique d'écriture : les XP sont attribués par le rôle de service
-- et par les triggers ci-dessus, jamais par le client. Un étudiant qui
-- pourrait insérer dans xp_events pourrait s'offrir la première place du
-- classement.

-- Les fonctions d'entretien écrivent dans profiles en SECURITY DEFINER :
-- elles ne sont appelables que par les triggers et le rôle de service.
revoke all on function public.refresh_streak(uuid) from public, anon, authenticated;
revoke all on function public.recompute_xp_total(uuid) from public, anon, authenticated;
