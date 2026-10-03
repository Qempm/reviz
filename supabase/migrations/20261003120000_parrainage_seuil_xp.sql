-- Parrainage : la commission s'ouvre à 3 000 XP (arbitrage du 3 octobre 2026).
--
-- Règle métier 2, complétée : un parrain ne touche sa commission sur les
-- paiements de ses filleuls qu'une fois 3 000 XP atteints — sauf ambassadeur,
-- choisi à la main pour recruter. Pas de rattrapage : un paiement fait avant le
-- seuil ne rapporte rien, et la fenêtre de douze mois part du premier paiement
-- commissionné (`first_payment_at` ne se pose qu'avec une commission).
--
-- La règle est décidée dans `lib/payments/commission.ts`. La base la
-- **revérifie** au moment d'écrire : `enregistrer_paiement` est redéfinie à
-- l'identique, signature comprise, avec le seuil en plus dans le bloc de la
-- commission. Les droits sont réappliqués tels quels.

create or replace function public.seuil_xp_parrainage()
returns integer
language sql
immutable
as $$
  select 3000;
$$;

comment on function public.seuil_xp_parrainage() is
  'XP qu''un parrain non ambassadeur doit avoir pour toucher ses commissions. '
  'Même valeur que SEUIL_XP_PARRAINAGE dans lib/payments/commission.ts.';

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
  v_parrain_debloque boolean := false;
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
  --
  -- Depuis le 3 octobre 2026, la base revérifie le seuil de 3 000 XP du
  -- parrain (sauf ambassadeur) : défense en profondeur, pour qu'un appelant
  -- qui régresserait ne puisse pas verser ce que la règle refuse. Le refus
  -- est silencieux, comme les autres : le filleul a payé, son accès s'ouvre.
  if p_parrain is not null then
    select coalesce(is_ambassador, false)
           or coalesce(xp_total, 0) >= public.seuil_xp_parrainage()
      into v_parrain_debloque
    from public.profiles
    where id = p_parrain;
  end if;

  if p_parrain is not null
     and coalesce(v_parrain_debloque, false)
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
  'La commission exige un parrain ambassadeur ou à 3 000 XP '
  '(seuil_xp_parrainage). '
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
