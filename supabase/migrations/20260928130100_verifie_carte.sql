-- Fige les droits de la vérification de carte, et la barrière qu'elle sert.
--
-- Septième migration d'assertion. Elle ne modifie rien.

do $$
declare
  f text := 'public.enregistrer_verification_carte(uuid, '
            'public.verification_status, text, timestamptz)';
  en_trop text[] := '{}';
  r text;
begin
  if to_regprocedure(f) is null then
    raise exception 'public.enregistrer_verification_carte est absente.';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'enregistrer_verification_carte'
      and p.prosecdef
  ) then
    raise exception
      'enregistrer_verification_carte n''est pas SECURITY DEFINER : elle ne '
      'pourrait plus écrire les colonnes que protect_profile_columns gèle.';
  end if;

  if not has_function_privilege('service_role', f, 'EXECUTE') then
    raise exception
      'Le rôle de service ne peut pas appeler enregistrer_verification_carte : '
      'plus aucune carte ne pourra être vérifiée.';
  end if;

  -- Un étudiant qui pourrait l'appeler se vérifierait lui-même, ce qui
  -- anéantit la règle métier 3. C'est la brèche que le lot 0 a refermée sur
  -- l'insertion de profil ; elle ne doit pas se rouvrir par une fonction.
  foreach r in array array['anon', 'authenticated'] loop
    if has_function_privilege(r, f, 'EXECUTE') then
      en_trop := en_trop || r;
    end if;
  end loop;

  if array_length(en_trop, 1) is not null then
    raise exception
      'enregistrer_verification_carte est exécutable par : %. Se vérifier '
      'soi-même anéantit la seule barrière « un compte par personne ».',
      array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits de la vérification de carte : conformes.';
end;
$$;

-- L'index qui **est** la barrière.
--
-- Toute la règle métier 3 repose sur lui depuis que le téléphone est
-- facultatif : sans unicité de l'empreinte, une personne ouvre autant de
-- comptes qu'elle veut avec une seule carte, se parraine elle-même et
-- encaisse 25 % de ses propres paiements. Il a existé sans jamais être
-- alimenté, faute de traitement `verify_card` ; il l'est maintenant, et son
-- absence deviendrait silencieuse.
do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'profiles_student_card_hash_idx'
      and indexdef ilike '%unique%'
  ) then
    raise exception
      'profiles_student_card_hash_idx n''est plus unique : une même carte '
      'pourrait ouvrir plusieurs comptes (règle métier 3).';
  end if;

  -- Et le gel de la colonne côté client : l'index ne sert à rien si le client
  -- peut écrire l'empreinte qu'il veut.
  if not exists (
    select 1 from pg_proc
    where proname = 'protect_profile_columns'
      and prosrc like '%student_card_hash%'
  ) then
    raise exception
      'protect_profile_columns ne gèle plus student_card_hash : un client '
      'pourrait s''attribuer l''empreinte qu''il veut.';
  end if;

  raise notice
    'Barrière « un compte par carte » : index unique en place, colonne gelée '
    'côté client.';
end;
$$;
