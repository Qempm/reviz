-- Commissions de parrainage suspendues ; taux ramenés à 10 % et 15 %
-- (arbitrage du 3 octobre 2026).
--
-- Le propriétaire, seul, ne peut pas tenir 25 % (35 % ambassadeur) de chaque
-- paiement : les commissions sont **suspendues**. Quand elles reviendront, ce
-- sera à 10 % pour un parrain, 15 % pour un ambassadeur — ces taux sont posés
-- dès maintenant, pour que la reprise ne soit qu'un interrupteur.
--
-- 1. `commissions_actives()` est l'interrupteur de la base. Il rend `false` :
--    `enregistrer_paiement` n'inscrit plus aucune commission, quoi que
--    l'appelant lui transmette. Le serveur porte le même interrupteur
--    (`COMMISSIONS_ACTIVES`, `lib/payments/commission.ts`), qui décide ; la
--    base revérifie, comme pour le seuil de 3 000 XP.
-- 2. La contrainte des taux accepte 10 % et 15 %. Elle garde 25 % et 35 % :
--    des parrainages déjà enregistrés les portent, et une contrainte qui les
--    refuserait ferait échouer la migration.
--
-- Rien n'est effacé : les commissions déjà inscrites restent dans le grand
-- livre, et un solde existant reste retirable.

create or replace function public.commissions_actives()
returns boolean
language sql
immutable
as $$
  select false;
$$;

comment on function public.commissions_actives() is
  'Interrupteur des commissions de parrainage. Suspendues depuis le 3 octobre '
  '2026. Même valeur que COMMISSIONS_ACTIVES dans lib/payments/commission.ts.';

alter table public.referrals
  drop constraint referrals_taux_connu;

-- 10 % et 15 % depuis le 3 octobre 2026 ; 25 % et 35 % pour les parrainages
-- enregistrés avant.
alter table public.referrals
  add constraint referrals_taux_connu
  check (commission_rate in (0.100, 0.150, 0.250, 0.350));

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
  --
  -- Depuis le 3 octobre 2026 aussi, l'interrupteur `commissions_actives()`
  -- passe avant tout : commissions suspendues, rien n'est inscrit.
  if p_parrain is not null and public.commissions_actives() then
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
  'La commission exige les commissions actives (commissions_actives) et un '
  'parrain ambassadeur ou à 3 000 XP (seuil_xp_parrainage). '
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
