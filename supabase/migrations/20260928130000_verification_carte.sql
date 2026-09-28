-- Écrire l'issue d'une vérification de carte étudiante.
--
-- La carte est **la seule barrière « un compte par personne »** depuis que le
-- téléphone est facultatif et non vérifié (règle métier 3). Sans elle, une
-- personne ouvre dix comptes, se parraine elle-même et encaisse 25 % de ses
-- propres paiements.
--
-- L'unicité est déjà tenue par `profiles_student_card_hash_idx`. Ce qui
-- manquait, c'est quoi faire quand il refuse : une violation d'unicité
-- remontée telle quelle ferait échouer le job, laisserait le profil en
-- `pending` pour toujours, et ne dirait rien à l'étudiant. Ici, elle devient
-- un refus motivé — « cette carte est déjà rattachée à un compte » — écrit
-- dans le profil.
--
-- Deux raisons de faire cela en SQL plutôt que dans l'application :
--
--  * l'écriture de l'empreinte et celle du statut doivent tenir ensemble ;
--  * deux dépôts simultanés de la même carte se croisent, et seule la base
--    peut trancher — c'est le propre d'une contrainte d'unicité.
--
-- `profiles.verification_status` et `student_card_hash` sont gelés pour le
-- client par `protect_profile_columns` ; cette fonction passe sous le rôle de
-- service, où le trigger laisse écrire.

create or replace function public.enregistrer_verification_carte(
  p_user uuid,
  p_statut public.verification_status,
  p_empreinte text default null,
  p_valide_jusqua timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deja uuid;
begin
  if not exists (select 1 from public.profiles where id = p_user) then
    return jsonb_build_object('resultat', 'profil-inconnu');
  end if;

  -- Sans empreinte — carte illisible, numéro introuvable — il n'y a rien à
  -- rendre unique : on écrit le statut seul.
  if p_empreinte is null then
    update public.profiles
    set verification_status = p_statut,
        verified_until = p_valide_jusqua
    where id = p_user;

    return jsonb_build_object('resultat', 'enregistre', 'statut', p_statut);
  end if;

  -- Déjà la sienne : un second dépôt de la même carte par le même étudiant
  -- n'est pas une fraude, c'est une reprise de photo.
  if exists (
    select 1 from public.profiles
    where id = p_user and student_card_hash = p_empreinte
  ) then
    update public.profiles
    set verification_status = p_statut,
        verified_until = p_valide_jusqua
    where id = p_user;

    return jsonb_build_object('resultat', 'enregistre', 'statut', p_statut);
  end if;

  select id into v_deja
  from public.profiles
  where student_card_hash = p_empreinte and id <> p_user
  limit 1;

  if found then
    -- On écrit le refus **sans** l'empreinte : elle appartient au premier
    -- compte, et la poser ici violerait l'index de toute façon.
    update public.profiles
    set verification_status = 'rejected',
        verified_until = null
    where id = p_user;

    return jsonb_build_object('resultat', 'deja-utilisee');
  end if;

  begin
    update public.profiles
    set verification_status = p_statut,
        student_card_hash = p_empreinte,
        verified_until = p_valide_jusqua
    where id = p_user;
  exception
    when unique_violation then
      -- Le contrôle ci-dessus a couru en même temps qu'un autre dépôt de la
      -- même carte. C'est exactement le cas que l'index existe pour trancher,
      -- et le perdant est refusé plutôt que mis en échec.
      update public.profiles
      set verification_status = 'rejected',
          verified_until = null
      where id = p_user;

      return jsonb_build_object('resultat', 'deja-utilisee');
  end;

  return jsonb_build_object('resultat', 'enregistre', 'statut', p_statut);
end;
$$;

comment on function public.enregistrer_verification_carte(
  uuid, public.verification_status, text, timestamptz
) is
  'Écrit le statut de vérification et l''empreinte de carte d''un profil. Une '
  'empreinte déjà portée par un autre compte donne un refus motivé au lieu '
  'd''une erreur d''unicité : c''est la règle métier 3, un compte par carte. '
  'Réservée au rôle de service — elle écrit des colonnes que le trigger '
  'protect_profile_columns gèle pour le client.';

-- Révoquer de PUBLIC **et** des rôles nommés avant d'accorder : les
-- privilèges par défaut de Supabase accordent EXECUTE nominativement à anon
-- comme à authenticated. Un étudiant qui pourrait appeler ceci se
-- vérifierait lui-même — ce qui est précisément la brèche que le lot 0 a
-- refermée sur l'insertion de profil.
revoke all on function public.enregistrer_verification_carte(
  uuid, public.verification_status, text, timestamptz
) from public;
revoke all on function public.enregistrer_verification_carte(
  uuid, public.verification_status, text, timestamptz
) from anon;
revoke all on function public.enregistrer_verification_carte(
  uuid, public.verification_status, text, timestamptz
) from authenticated;
grant execute on function public.enregistrer_verification_carte(
  uuid, public.verification_status, text, timestamptz
) to service_role;
