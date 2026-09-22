-- L'heure d'une réponse est celle du serveur, et la question doit être lisible.
--
-- La politique « J'enregistre mes réponses » (20260908120600_rls.sql:206-209)
-- ne contrôle que `user_id = auth.uid()`. Deux colonnes restaient à la main
-- du client :
--
-- * `answered_at` décide du jour dans `track_attempt()`
--   (20260908140000:187) **et** de la fenêtre du plafond de 300 réponses par
--   jour (20260908120300:148). Un client pouvait antidater pour se fabriquer
--   une série de plusieurs jours en une requête, ou repartir à zéro sur le
--   plafond quotidien.
--
-- * `question_id` n'était contraint à rien : on pouvait répondre à une
--   question d'un cours qu'on n'a pas le droit de lire, ce qui fait entrer
--   dans `subject_stats` et `chapter_stats` des matières étrangères.

-- 1. L'horodatage vient du serveur ---------------------------------------

create or replace function public.force_attempt_timestamp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le rôle de service garde la main : une reprise de données ou un
  -- rattrapage doit pouvoir poser une date passée.
  if auth.uid() is null then
    return new;
  end if;

  new.answered_at := now();
  return new;
end;
$$;

comment on function public.force_attempt_timestamp() is
  'L''heure d''une réponse est celle du serveur. Sans cela, antidater '
  '`answered_at` forge une série et contourne le plafond quotidien.';

create trigger attempts_force_timestamp
  before insert on public.attempts
  for each row
  execute function public.force_attempt_timestamp();

revoke all on function public.force_attempt_timestamp() from public;
revoke all on function public.force_attempt_timestamp() from anon;

-- Ce trigger doit passer **avant** `attempts_track_activity`, qui lit
-- `new.answered_at` pour choisir le jour. Les triggers d'un même moment
-- s'exécutent par ordre alphabétique de nom : `attempts_daily_cap` puis
-- `attempts_force_timestamp` en BEFORE, et `attempts_track_activity` en
-- AFTER — donc après les deux. L'ordre est bon.
--
-- Reste que `attempts_daily_cap` compte sur `date_trunc('day', now())` et
-- non sur `new.answered_at` : il ne dépend pas de ce trigger.

-- 2. La question doit être lisible par l'appelant ------------------------

-- Une politique ne se modifie pas en place.
drop policy if exists "J'enregistre mes réponses" on public.attempts;

create policy "J'enregistre mes réponses"
  on public.attempts for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.questions q
      join public.chapters c on c.id = q.chapter_id
      where q.id = attempts.question_id
        and public.can_read_course(c.course_id)
    )
  );
