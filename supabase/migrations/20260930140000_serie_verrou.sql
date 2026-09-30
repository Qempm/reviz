-- La série ne démarrait jamais : le verrou de `profiles` l'annulait.
--
-- Trouvé en essai de bout en bout le 30 septembre 2026 : une journée validée
-- (`daily_activity.is_validated`) laissait `current_streak`, `longest_streak`
-- et `last_validated_on` à zéro.
--
-- La chaîne : les réponses sont insérées **sous l'identité de l'étudiant**
-- (`lib/metier/session.ts`) ; `track_attempt()` valide la journée et appelle
-- `refresh_streak()`, qui met à jour `profiles` ; `protect_profile_columns()`
-- voit alors `auth.uid() = old.id` — c'est toujours la requête de l'étudiant —
-- et remet les colonnes de gamification à leur ancienne valeur. Son
-- commentaire supposait que ces traitements tournaient « sans auth.uid() » :
-- vrai pour l'XP (écrite par le rôle de service), faux pour la série.
--
-- Correction : une mise à jour qui vient d'un autre déclencheur
-- (`pg_trigger_depth() > 1`) est un traitement interne, qui calcule lui-même
-- ses valeurs ; elle passe. Une mise à jour envoyée directement par un client
-- reste à la profondeur 1, et reste verrouillée.

create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le rôle de service, les traitements internes (appelés depuis un autre
  -- déclencheur : `track_attempt()` → `refresh_streak()`), gardent la main.
  if auth.uid() is null or auth.uid() <> old.id or pg_trigger_depth() > 1 then
    return new;
  end if;

  new.verification_status := old.verification_status;
  new.verified_until      := old.verified_until;
  new.is_ambassador       := old.is_ambassador;
  new.referral_code       := old.referral_code;
  new.student_card_hash   := old.student_card_hash;
  new.referred_by         := old.referred_by;

  new.xp_total          := old.xp_total;
  new.current_streak    := old.current_streak;
  new.longest_streak    := old.longest_streak;
  new.last_validated_on := old.last_validated_on;

  return new;
end;
$$;

-- Les séries perdues : recalculées depuis les journées validées, qui, elles,
-- ont toujours été enregistrées. Sans rôle client ici (`auth.uid()` nul), le
-- verrou laisse passer.
do $$
declare
  u uuid;
begin
  for u in
    select distinct user_id from public.daily_activity where is_validated
  loop
    perform public.refresh_streak(u);
  end loop;
end;
$$;
