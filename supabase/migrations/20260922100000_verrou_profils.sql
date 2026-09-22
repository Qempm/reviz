-- Referme les colonnes de `profiles` que le client ne doit pas écrire.
--
-- Deux trous, constatés le 22 septembre 2026 :
--
-- 1. `protect_profile_columns()` (20260908120600_rls.sql:110-131) gèle six
--    colonnes. Les quatre compteurs de gamification ont été ajoutés à la
--    table **plus tard le même jour** (20260908140000_xp_et_series.sql:72-76)
--    et le trigger n'a jamais suivi. La politique d'UPDATE autorisant
--    `id = auth.uid()`, un `update profiles set xp_total = 999999` passait.
--
--    Le commentaire de 20260908140000:329-332 ferme soigneusement l'écriture
--    de `xp_events` « parce qu'un étudiant qui pourrait s'y insérer
--    s'offrirait la première place du classement ». La voie directe par
--    `profiles.xp_total` est restée ouverte — et c'est précisément la colonne
--    que lit le classement.
--
-- 2. Le verrou n'existait qu'en UPDATE. Aucun trigger `before insert`, et la
--    politique « Je crée mon profil » ne contrôle que `id = auth.uid()` : à
--    l'inscription, le client posait lui-même `verification_status`,
--    `is_ambassador`, `student_card_hash` et ses compteurs. C'est-à-dire se
--    vérifier sans carte étudiante — seule barrière « un compte par personne »
--    depuis que le téléphone est facultatif (CLAUDE.md, règle 3) — et
--    s'octroyer le taux ambassadeur à 35 %.
--
-- Ces deux trous deviennent urgents avec le passage à Flutter : la clé
-- anonyme quitte un bundle web pour un APK décompilable, et le client écrit
-- en direct dans PostgREST.

-- 1. UPDATE : ajouter les quatre compteurs à la liste gelée ---------------

create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le rôle de service et les traitements internes gardent la main.
  if auth.uid() is null or auth.uid() <> old.id then
    return new;
  end if;

  new.verification_status := old.verification_status;
  new.verified_until      := old.verified_until;
  new.is_ambassador       := old.is_ambassador;
  new.referral_code       := old.referral_code;
  new.student_card_hash   := old.student_card_hash;
  new.referred_by         := old.referred_by;

  -- Gamification : tenue par les triggers `track_xp_event()` et
  -- `refresh_streak()`, qui tournent en SECURITY DEFINER sans `auth.uid()`
  -- et passent donc par la porte ci-dessus.
  new.xp_total          := old.xp_total;
  new.current_streak    := old.current_streak;
  new.longest_streak    := old.longest_streak;
  new.last_validated_on := old.last_validated_on;

  return new;
end;
$$;

comment on function public.protect_profile_columns() is
  'Regèle sur `old` les colonnes de profiles réservées aux traitements : '
  'vérification, parrainage, et les quatre compteurs de gamification. Une '
  'politique RLS accorde ou refuse une ligne entière, elle ne sait pas '
  'protéger une colonne.';

-- 2. INSERT : le même verrou, à la création ------------------------------

create or replace function public.protect_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Rôle de service : l'inscription côté serveur doit pouvoir poser un
  -- parrainage vérifié ou rattraper un compte à la main.
  if auth.uid() is null then
    return new;
  end if;

  -- Un client ne crée que son propre profil, et vierge.
  new.verification_status := 'none';
  new.verified_until      := null;
  new.is_ambassador       := false;
  new.student_card_hash   := null;

  new.xp_total          := 0;
  new.current_streak    := 0;
  new.longest_streak    := 0;
  new.last_validated_on := null;

  -- Toujours régénéré : un code choisi par le client serait prévisible, ou
  -- squatterait celui d'un camarade. La valeur par défaut de la colonne est
  -- déjà appliquée avant ce trigger, mais rien ne distingue ici une valeur
  -- par défaut d'une valeur fournie — on tranche donc en la refaisant.
  new.referral_code := public.generate_referral_code();

  -- `referred_by` reste permis : c'est le parcours d'inscription légitime, et
  -- le désigner ne profite pas à celui qui le pose — la commission va au
  -- parrain. Le trigger d'UPDATE le gèle ensuite. La création de profil part
  -- de toute façon côté serveur au lot suivant, et cette politique
  -- d'insertion pourra alors se fermer complètement.

  return new;
end;
$$;

comment on function public.protect_profile_insert() is
  'Pendant de protect_profile_columns() à la création : un client ne '
  's''inscrit ni vérifié, ni ambassadeur, ni avec des XP.';

create trigger profiles_protect_insert
  before insert on public.profiles
  for each row
  execute function public.protect_profile_insert();

-- Les fonctions de trigger n'ont pas à être appelables en RPC. Révoquer de
-- PUBLIC **et** de anon : les privilèges par défaut de Supabase accordent
-- EXECUTE nominativement à anon, ce qui survit à une révocation de PUBLIC
-- (leçon de 20260909150000_revoque_anon.sql).
revoke all on function public.protect_profile_insert() from public;
revoke all on function public.protect_profile_insert() from anon;
revoke all on function public.protect_profile_columns() from public;
revoke all on function public.protect_profile_columns() from anon;
