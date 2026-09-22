-- Un paiement réussi ne s'enregistre qu'une fois, et d'un seul bloc.
--
-- Le webhook actuel fait quatre écritures indépendantes : statut du paiement,
-- abonnement, commission, `first_payment_at`. Deux défauts en découlent, tous
-- deux constatés dans le code :
--
--   * **Il paie deux fois.** Le commentaire affirme « idempotence : unique
--     constraint sur provider + provider_ref ». Cette contrainte empêche un
--     doublon de *ligne* `payments` ; elle n'empêche rien du retraitement du
--     même événement. Le code lit `payment.status` et ne le teste jamais.
--     FedaPay, comme tout émetteur de webhook, réémet : à la deuxième
--     livraison de `approved`, l'étudiant reçoit un second abonnement — car
--     `activerPack()` cumule les packs par conception — et le parrain une
--     seconde commission, dans un journal volontairement immuable que seule
--     une ligne `adjustment` peut corriger.
--   * **Une panne au milieu laisse la base à moitié écrite** : abonnement
--     posé, commission absente, ou l'inverse.
--
-- Cette fonction règle les deux. Le `for update` sur la ligne de paiement
-- sérialise les relivraisons : la seconde attend la première, la voit à
-- `success` et repart sans rien écrire. Et une fonction plpgsql est une seule
-- transaction, donc les quatre écritures tiennent ou échouent ensemble.
--
-- Les deux index uniques ajoutés plus bas sont la ceinture par-dessus les
-- bretelles : même en cas de bogue applicatif, un paiement ne peut plus
-- porter deux abonnements ni deux commissions.

-- Avant de poser les index : dire ce qui bloque, s'il y a déjà des doublons.
--
-- Si le webhook a déjà payé deux fois quelqu'un, la création de l'index
-- échouerait sur un message de contrainte illisible. Autant nommer les lignes
-- à réconcilier — par une ligne `adjustment`, le grand livre étant immuable.
do $$
declare
  abonnements text;
  commissions text;
begin
  select string_agg(distinct payment_id::text, ', ')
  into abonnements
  from (
    select payment_id
    from public.subscriptions
    where payment_id is not null
    group by payment_id
    having count(*) > 1
  ) d;

  select string_agg(distinct reference_id::text, ', ')
  into commissions
  from (
    select reference_id
    from public.wallet_ledger
    where type = 'referral_commission' and reference_id is not null
    group by reference_id
    having count(*) > 1
  ) d;

  if abonnements is not null then
    raise exception
      'Des paiements portent déjà plusieurs abonnements : %. Les réconcilier '
      'avant de poser l''index unique.', abonnements;
  end if;

  if commissions is not null then
    raise exception
      'Des paiements ont déjà été commissionnés plusieurs fois : %. '
      'Compenser par une ligne adjustment avant de poser l''index unique.',
      commissions;
  end if;

  raise notice 'Paiements : aucun doublon d''abonnement ni de commission.';
end;
$$;

-- Un paiement n'émet qu'un abonnement.
--
-- Partiel sur `payment_id is not null` : les abonnements offerts
-- (`source = 'bonus'`) et les achats de classe n'ont pas de paiement, et
-- doivent rester libres.
create unique index if not exists subscriptions_un_par_paiement_idx
  on public.subscriptions (payment_id)
  where payment_id is not null;

comment on index public.subscriptions_un_par_paiement_idx is
  'Un paiement n''ouvre qu''un accès. La relivraison d''un webhook ne peut '
  'plus doubler la durée d''un pack.';

-- Un paiement n'émet qu'une commission.
create unique index if not exists wallet_ledger_une_commission_par_paiement_idx
  on public.wallet_ledger (reference_id)
  where type = 'referral_commission' and reference_id is not null;

comment on index public.wallet_ledger_une_commission_par_paiement_idx is
  'Une commission de parrainage par paiement. Le grand livre étant immuable, '
  'un doublon ne se corrigerait que par une ligne adjustment.';

-- Enregistre l'issue d'un paiement.
--
-- Les valeurs de l'abonnement et de la commission sont **calculées par
-- l'appelant**, dans `lib/payments/subscriptions.ts` et
-- `lib/payments/commission.ts` — les deux modules purs que couvrent leurs
-- tests. Elles ne sont pas recalculées ici : la règle métier a un seul
-- porteur, et le rapport d'audit relevait précisément que le webhook la
-- réécrivait en deux lignes au lieu de l'appeler.
--
-- Ce que la fonction garde pour elle, parce que cela ne peut pas être décidé
-- hors transaction : la prise du paiement, et l'ordre des écritures.
create or replace function public.enregistrer_paiement(
  p_provider text,
  p_provider_ref text,
  p_statut public.payment_status,
  p_brut jsonb default null,
  p_debut timestamptz default null,
  p_fin timestamptz default null,
  p_corrections integer default null,
  p_parrain uuid default null,
  p_commission_fcfa integer default null,
  p_taux numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paiement public.payments;
  v_abonnement uuid;
  v_commission uuid;
begin
  -- Sérialise les relivraisons du même événement. Tout le reste en dépend.
  select * into v_paiement
  from public.payments
  where provider = p_provider
    and provider_ref = p_provider_ref
  for update;

  if not found then
    -- Transaction inconnue : l'appelant répondra 200, sans quoi le
    -- fournisseur réessaiera indéfiniment un événement qui ne nous concerne
    -- pas.
    return jsonb_build_object('resultat', 'inconnu');
  end if;

  if v_paiement.status = 'success' then
    return jsonb_build_object(
      'resultat', 'deja-traite',
      'paiement_id', v_paiement.id
    );
  end if;

  update public.payments
  set status = p_statut,
      raw = coalesce(p_brut, raw)
  where id = v_paiement.id;

  if p_statut <> 'success' then
    return jsonb_build_object(
      'resultat', 'echec-enregistre',
      'paiement_id', v_paiement.id
    );
  end if;

  if p_fin is null then
    raise exception
      'Un paiement réussi exige une fin d''accès : p_fin est NULL pour le '
      'paiement %.', v_paiement.id;
  end if;

  insert into public.subscriptions (
    user_id, pack_code, starts_at, ends_at, corrections_left, source, payment_id
  )
  values (
    v_paiement.user_id,
    v_paiement.pack_code,
    coalesce(p_debut, now()),
    p_fin,
    coalesce(p_corrections, 0),
    'payment',
    v_paiement.id
  )
  returning id into v_abonnement;

  -- La commission n'est versée que si l'appelant l'a jugée due. Un parrain
  -- sans montant, ou un montant nul, n'écrit rien : c'est un refus légitime
  -- (filleul non vérifié, fenêtre de douze mois close), pas une erreur.
  if p_parrain is not null
     and p_commission_fcfa is not null
     and p_commission_fcfa > 0 then

    insert into public.wallet_ledger (
      user_id, type, amount_fcfa, reference_id, note
    )
    values (
      p_parrain,
      'referral_commission',
      p_commission_fcfa,
      v_paiement.id,
      'Commission sur le paiement ' || v_paiement.id
    )
    returning id into v_commission;

    -- `first_payment_at` n'est posé qu'une fois : le trigger
    -- `referrals_expiry` en déduit `expires_at`, et la fenêtre de douze mois
    -- ne doit pas se rouvrir à chaque paiement suivant.
    update public.referrals
    set first_payment_at = coalesce(first_payment_at, now()),
        commission_rate = coalesce(p_taux, commission_rate)
    where referrer_id = p_parrain
      and referred_id = v_paiement.user_id;
  end if;

  return jsonb_build_object(
    'resultat', 'traite',
    'paiement_id', v_paiement.id,
    'abonnement_id', v_abonnement,
    'commission_id', v_commission
  );
end;
$$;

comment on function public.enregistrer_paiement(
  text, text, public.payment_status, jsonb, timestamptz, timestamptz,
  integer, uuid, integer, numeric
) is
  'Enregistre l''issue d''un paiement en une seule transaction : prise du '
  'paiement par for update, statut, abonnement, commission, first_payment_at. '
  'Rend « deja-traite » sur une relivraison, sans rien écrire. Réservée au '
  'rôle de service : elle écrit dans les tables financières.';

-- Révoquer de PUBLIC **et** des rôles nommés avant d'accorder : révoquer
-- PUBLIC ne retire pas un droit accordé nominativement, et les privilèges par
-- défaut de Supabase accordent EXECUTE à anon comme à authenticated. C'est le
-- motif qui a coûté quatre passes de correction sur d'autres fonctions.
revoke all on function public.enregistrer_paiement(
  text, text, public.payment_status, jsonb, timestamptz, timestamptz,
  integer, uuid, integer, numeric
) from public;

revoke all on function public.enregistrer_paiement(
  text, text, public.payment_status, jsonb, timestamptz, timestamptz,
  integer, uuid, integer, numeric
) from anon;

revoke all on function public.enregistrer_paiement(
  text, text, public.payment_status, jsonb, timestamptz, timestamptz,
  integer, uuid, integer, numeric
) from authenticated;

grant execute on function public.enregistrer_paiement(
  text, text, public.payment_status, jsonb, timestamptz, timestamptz,
  integer, uuid, integer, numeric
) to service_role;
