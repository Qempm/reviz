-- Fige les droits du classement, et garde la liste des colonnes qui sortent.
--
-- `20260922100300_verifie_verrous.sql` n'attrape que ce qu'il nomme : il a
-- fallu l'écrire pour que `get_user_rank` ne se rouvre pas, et il faut
-- l'étendre ici pour les deux fonctions du classement. C'est la limite
-- reconnue de ce genre d'assertion, et la raison de l'ajouter à chaque fois.
--
-- Cette migration ne modifie rien.

do $$
declare
  manquant text[] := '{}';
  en_trop text[] := '{}';

  requis text[] := array[
    'public.classement_faculte(integer)',
    'public.mon_rang_faculte()'
  ];

  f text;
begin
  foreach f in array requis loop
    if to_regprocedure(f) is null then
      manquant := manquant || (f || ' (absente)');
    elsif not has_function_privilege('authenticated', f, 'EXECUTE') then
      manquant := manquant || f;
    elsif has_function_privilege('anon', f, 'EXECUTE') then
      en_trop := en_trop || (f || ' → anon');
    end if;
  end loop;

  if array_length(manquant, 1) is not null then
    raise exception 'Droits manquants : %', array_to_string(manquant, ', ');
  end if;
  if array_length(en_trop, 1) is not null then
    raise exception 'Droits en trop : %', array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits du classement : conformes.';
end;
$$;

-- Ce que le classement laisse sortir.
--
-- L'intérêt de cette assertion n'est pas le droit mais la **forme** : ajouter
-- une colonne à la sortie de `classement_faculte` — un identifiant, un
-- téléphone, un statut de vérification — est précisément ce qu'il ne faut pas
-- faire par inadvertance. Le déploiement s'arrête si la signature change.

do $$
declare
  attendu text := 'rang integer, prenom text, avatar_key text, '
                  'xp_total integer, est_moi boolean';
  obtenu text;
begin
  select pg_get_function_result(oid) into obtenu
  from pg_proc
  where oid = 'public.classement_faculte(integer)'::regprocedure;

  -- `pg_get_function_result` rend « TABLE(rang integer, …) ».
  obtenu := replace(replace(obtenu, 'TABLE(', ''), ')', '');

  if obtenu is distinct from attendu then
    raise exception
      'La sortie de classement_faculte a changé. Attendu « % », obtenu '
      '« % ». Un classement ne doit jamais rendre d''identifiant ni de '
      'donnée sensible : « c''est toi » se lit sur est_moi.',
      attendu, obtenu;
  end if;

  raise notice 'Sortie du classement : les 5 colonnes attendues, sans identifiant.';
end;
$$;
