-- Vérifie l'état des droits sur les fonctions, et échoue s'il dérive.
--
-- Trois migrations ont été nécessaires pour fermer correctement les fonctions
-- SECURITY DEFINER (PUBLIC, puis le droit nominatif `anon` posé par les
-- privilèges par défaut de Supabase). Cette migration fige le résultat sous
-- forme d'assertions : si une future migration recrée une fonction sans la
-- refermer, le déploiement s'arrête ici au lieu de rouvrir la brèche
-- silencieusement.
--
-- Elle ne modifie rien.

do $$
declare
  manquant text[] := '{}';
  en_trop text[] := '{}';

  -- Fonctions que `authenticated` DOIT pouvoir appeler.
  -- current_faculty_id et can_read_course sont évaluées dans les politiques
  -- RLS avec les droits de l'appelant : sans EXECUTE, toute lecture de cours
  -- échouerait. generate_referral_code est la valeur par défaut de
  -- profiles.referral_code, évaluée à l'INSERT du profil.
  requis text[] := array[
    'public.wallet_balance()',
    'public.streak_week(date)',
    'public.current_faculty_id()',
    'public.can_read_course(uuid)',
    'public.generate_referral_code()',
    'public.daily_goal()'
  ];

  -- Fonctions qu'aucun rôle client ne doit pouvoir appeler.
  interdit text[] := array[
    'public.refresh_streak(uuid)',
    'public.recompute_xp_total(uuid)',
    'public.claim_jobs(integer, interval)',
    'public.job_peut_demarrer(public.job_type, timestamptz, timestamptz)'
  ];

  f text;
begin
  foreach f in array requis loop
    if not has_function_privilege('authenticated', f, 'EXECUTE') then
      manquant := manquant || f;
    end if;
    -- Aucune de ces fonctions ne doit être atteignable avant connexion.
    if has_function_privilege('anon', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' [anon]');
    end if;
  end loop;

  foreach f in array interdit loop
    if has_function_privilege('anon', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' [anon]');
    end if;
    if has_function_privilege('authenticated', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' [authenticated]');
    end if;
  end loop;

  if array_length(manquant, 1) is not null then
    raise exception
      'Droit EXECUTE manquant pour authenticated : %. Les politiques RLS ou '
      'la création de profil échoueraient.', array_to_string(manquant, ', ');
  end if;

  if array_length(en_trop, 1) is not null then
    raise exception
      'Droit EXECUTE de trop : %. Révoquer de PUBLIC ET du rôle nommé.',
      array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits sur les fonctions conformes : % requises, % interdites.',
    array_length(requis, 1), array_length(interdit, 1);
end;
$$;
