-- Supprimer son compte, quand la base refuse de le supprimer.
--
-- L'état constaté : `app/api/profile/delete/route.ts` appelle
-- `admin.auth.admin.deleteUser()` et affirme en commentaire que « Supabase
-- supprime automatiquement les données associées via RLS et cascades ». Les
-- deux moitiés sont fausses.
--
-- `profiles.id` cascade bien depuis `auth.users`, mais la cascade s'arrête net
-- sur `profiles` :
--
--   * `payments.user_id`, `wallet_ledger.user_id` et `withdrawals.user_id`
--     sont en `on delete restrict` — et `payments` reçoit une ligne `pending`
--     dès qu'un pack payant est effleuré, même sans payer ;
--   * `xp_events` porte un trigger `xp_events_no_delete` qui lève sur tout
--     DELETE, **y compris pour le rôle de service**.
--
-- Donc : tout étudiant ayant gagné un seul point d'XP ou touché un pack ne
-- pouvait pas supprimer son compte, et n'obtenait qu'un 500 opaque. Les
-- objets de stockage n'étaient pas supprimés non plus.
--
-- **On anonymise au lieu de supprimer.** C'est ce que demande un grand livre
-- immuable : les montants restent, l'identité s'en va. Le compte devient
-- inutilisable — adresse inerte, identités détachées, sessions révoquées,
-- connexion bannie — et plus rien ne permet de savoir à qui appartenaient les
-- lignes financières.
--
-- Ce qui part : prénom, téléphone, empreinte de carte étudiante, avatar,
-- université, filière, année, code de parrainage, cours déposés (avec leurs
-- chapitres, questions et fiches), réponses, corrections, activité
-- quotidienne, parrainages.
--
-- Ce qui reste : `payments`, `wallet_ledger`, `withdrawals` et `xp_events`,
-- sans nom dessus. Et `subscriptions`, qui cascade depuis `profiles` mais
-- n'est pas supprimée ici : un abonnement est la contrepartie d'un paiement
-- conservé, le retirer rendrait le grand livre incompréhensible.
--
-- Les **fichiers** du stockage ne sont pas effacés ici : supprimer une ligne
-- de `storage.objects` retire la référence mais laisse le binaire sur S3.
-- C'est la route qui les retire par l'API de stockage, avant d'appeler cette
-- fonction.

create or replace function public.anonymiser_compte(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_marque constant text := '@compte-supprime.invalid';
  v_cours integer;
  v_corrections integer;
  v_reponses integer;
begin
  select u.email into v_email from auth.users u where u.id = p_user;

  if not found then
    return jsonb_build_object('resultat', 'inconnu');
  end if;

  -- Idempotent : une seconde demande ne doit pas échouer ni tout refaire.
  if v_email like ('%' || v_marque) then
    return jsonb_build_object('resultat', 'deja-anonymise');
  end if;

  -- 1. Le contenu personnel qui peut disparaître.
  --
  -- Les réponses d'abord, et explicitement : `attempts.user_id` cascade
  -- depuis `profiles`, qu'on ne supprime pas, et `attempts.question_id`
  -- cascade depuis `questions` — ce qui ne couvre que les réponses données
  -- sur ses **propres** cours. Celles données sur un cours partagé par
  -- quelqu'un d'autre survivraient à la suppression des cours.
  delete from public.attempts where user_id = p_user;
  get diagnostics v_reponses = row_count;

  delete from public.daily_activity where user_id = p_user;

  delete from public.corrections where user_id = p_user;
  get diagnostics v_corrections = row_count;

  -- `courses` cascade vers `chapters`, donc vers `questions` et `flashcards`.
  delete from public.courses where owner_id = p_user;
  get diagnostics v_cours = row_count;

  -- Les parrainages, des deux côtés. Côté parrain, c'est ce qui coupe les
  -- commissions futures sur un compte qui n'existe plus ; côté filleul, cela
  -- retire la créance d'un tiers sur quelqu'un qui est parti. Les commissions
  -- déjà versées restent dans le grand livre.
  delete from public.referrals
  where referrer_id = p_user or referred_id = p_user;

  -- 2. Le profil, vidé.
  --
  -- `referral_code` est `not null unique` : il prend une valeur morte plutôt
  -- que NULL, et volontairement pas un code de la forme qu'engendre
  -- `generate_referral_code()` — un code d'allure normale pourrait être
  -- repartagé.
  update public.profiles
  set first_name = null,
      phone = null,
      student_card_hash = null,
      avatar_key = null,
      university_id = null,
      faculty_id = null,
      study_year = null,
      verification_status = 'none',
      verified_until = null,
      is_ambassador = false,
      referred_by = null,
      referral_code = 'SUPPR-' || replace(p_user::text, '-', '')
  where id = p_user;

  -- `profiles.referred_by` d'autres comptes peut encore pointer ici : la
  -- colonne est en `on delete set null`, et la ligne n'est pas supprimée. Ce
  -- pointeur est inoffensif — la ligne `referrals` qui portait la créance
  -- vient d'être retirée, et `deciderPaiement()` ne verse rien sans elle.

  -- 3. Le compte d'authentification, rendu inutilisable.
  --
  -- L'adresse part sur `.invalid`, domaine réservé par la RFC 2606 : aucun
  -- code de connexion ne pourra plus y arriver. Les identités fédérées
  -- (Google) sont détachées, sans quoi une reconnexion se rattacherait au
  -- même compte. Les sessions sont révoquées, sinon le jeton en cours
  -- resterait valable des semaines. Et `banned_until` ferme la porte même si
  -- l'un des trois précédents était contourné.
  delete from auth.identities where user_id = p_user;
  delete from auth.sessions where user_id = p_user;

  update auth.users
  set email = 'supprime-' || replace(p_user::text, '-', '') || v_marque,
      phone = null,
      email_change = '',
      phone_change = '',
      raw_user_meta_data = '{}'::jsonb,
      banned_until = 'infinity'
  where id = p_user;

  return jsonb_build_object(
    'resultat', 'anonymise',
    'cours_supprimes', v_cours,
    'corrections_supprimees', v_corrections,
    'reponses_supprimees', v_reponses
  );
end;
$$;

comment on function public.anonymiser_compte(uuid) is
  'Vide l''identité d''un compte et supprime son contenu personnel, sans '
  'toucher aux lignes financières — payments, wallet_ledger, withdrawals et '
  'xp_events les refusent, le grand livre étant immuable. Le compte devient '
  'inutilisable : adresse sur .invalid, identités détachées, sessions '
  'révoquées, connexion bannie. Idempotente. Les fichiers du stockage sont '
  'retirés par l''appelant, par l''API de stockage.';

-- Révoquer de PUBLIC **et** des rôles nommés avant d'accorder : les
-- privilèges par défaut de Supabase accordent EXECUTE nominativement à anon
-- comme à authenticated, et révoquer PUBLIC ne retire pas un droit nominatif.
-- Une fonction qui vide un profil et bannit un compte ne doit être appelable
-- que par le serveur, après qu'il a vérifié qui demande.
revoke all on function public.anonymiser_compte(uuid) from public;
revoke all on function public.anonymiser_compte(uuid) from anon;
revoke all on function public.anonymiser_compte(uuid) from authenticated;
grant execute on function public.anonymiser_compte(uuid) to service_role;
