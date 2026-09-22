-- Fige les verrous de la phase 0 sous forme d'assertions.
--
-- `20260909160000_verifie_droits.sql` avait déjà figé les droits des
-- fonctions — et n'a pourtant pas attrapé `get_user_rank`, parce que sa liste
-- `interdit` datait d'avant. Une liste d'assertions n'attrape que ce qu'elle
-- nomme : celle-ci nomme ce que la phase 0 vient de poser, et sera à son tour
-- à compléter.
--
-- Elle ne modifie rien.

-- 1. Droits des fonctions ------------------------------------------------

do $$
declare
  manquant text[] := '{}';
  en_trop text[] := '{}';

  requis text[] := array[
    'public.get_user_rank()'
  ];

  interdit text[] := array[
    'public.get_user_rank(uuid)',
    'public.protect_profile_insert()',
    'public.protect_profile_columns()',
    'public.force_attempt_timestamp()'
  ];

  f text;
begin
  foreach f in array requis loop
    -- `to_regprocedure` renvoie NULL si la fonction n'existe pas : on le
    -- distingue d'un droit manquant, sinon le message est trompeur.
    if to_regprocedure(f) is null then
      manquant := manquant || (f || ' (absente)');
    elsif not has_function_privilege('authenticated', f, 'EXECUTE') then
      manquant := manquant || f;
    elsif has_function_privilege('anon', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' → anon');
    end if;
  end loop;

  foreach f in array interdit loop
    if to_regprocedure(f) is null then
      continue;  -- absente, donc inoffensive
    end if;
    if has_function_privilege('authenticated', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' → authenticated');
    end if;
    if has_function_privilege('anon', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' → anon');
    end if;
  end loop;

  if array_length(manquant, 1) is not null then
    raise exception 'Droits manquants : %', array_to_string(manquant, ', ');
  end if;

  if array_length(en_trop, 1) is not null then
    raise exception 'Droits en trop : %', array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits des fonctions de la phase 0 : conformes.';
end;
$$;

-- 2. Présence des triggers de verrouillage -------------------------------

do $$
declare
  attendus text[] := array[
    'profiles_protect_columns',
    'profiles_protect_insert',
    'attempts_force_timestamp',
    'courses_protect_status'
  ];
  t text;
  absents text[] := '{}';
begin
  foreach t in array attendus loop
    if not exists (
      select 1 from pg_trigger
      where tgname = t and not tgisinternal
    ) then
      absents := absents || t;
    end if;
  end loop;

  if array_length(absents, 1) is not null then
    raise exception 'Triggers de verrouillage absents : %',
      array_to_string(absents, ', ');
  end if;

  raise notice 'Triggers de verrouillage : présents.';
end;
$$;

-- 3. Les colonnes réellement gelées --------------------------------------
--
-- C'est l'assertion qui manquait le 8 septembre : `protect_profile_columns`
-- a été écrit à 12:06, les quatre compteurs de gamification ajoutés à 14:00,
-- et personne n'a rapproché les deux. On compare donc la source de la
-- fonction à la liste des colonnes sensibles, pour qu'ajouter une colonne
-- sans l'y inscrire arrête le déploiement.

do $$
declare
  source text;
  sensibles text[] := array[
    'verification_status',
    'verified_until',
    'is_ambassador',
    'referral_code',
    'student_card_hash',
    'referred_by',
    'xp_total',
    'current_streak',
    'longest_streak',
    'last_validated_on'
  ];
  c text;
  oubliees text[] := '{}';
begin
  select prosrc into source
  from pg_proc
  where oid = 'public.protect_profile_columns()'::regprocedure;

  foreach c in array sensibles loop
    if position(c in source) = 0 then
      oubliees := oubliees || c;
    end if;
  end loop;

  if array_length(oubliees, 1) is not null then
    raise exception
      'protect_profile_columns() ne gèle pas : %. Une politique RLS accorde '
      'une ligne entière, elle ne protège pas une colonne.',
      array_to_string(oubliees, ', ');
  end if;

  raise notice 'Colonnes gelées de profiles : les % sensibles y sont.',
    array_length(sensibles, 1);
end;
$$;
