-- Fige les droits et les garde-fous du paiement.
--
-- Même motif que `20260922100300_verifie_verrous.sql` et
-- `20260922110100_verifie_classement.sql` : ces assertions n'attrapent que ce
-- qu'elles nomment, il faut donc les étendre à chaque fonction sensible. C'est
-- la limite reconnue de l'exercice, et la raison de le refaire à chaque fois.
--
-- Cette migration ne modifie rien.

do $$
declare
  -- Signature entièrement qualifiée : une assertion ne doit pas dépendre du
  -- `search_path` de la session qui applique la migration.
  f text := 'public.enregistrer_paiement(text, text, public.payment_status, '
            'jsonb, timestamptz, timestamptz, integer, uuid, integer, '
            'numeric)';
  en_trop text[] := '{}';
  r text;
begin
  if to_regprocedure(f) is null then
    raise exception 'public.enregistrer_paiement est absente.';
  end if;

  if not has_function_privilege('service_role', f, 'EXECUTE') then
    raise exception
      'Le rôle de service ne peut pas appeler enregistrer_paiement : le '
      'webhook ne pourra plus rien enregistrer.';
  end if;

  -- Cette fonction écrit dans `payments`, `subscriptions`, `wallet_ledger` et
  -- `referrals`. Un étudiant qui pourrait l'appeler s'offrirait un pack et
  -- une commission.
  foreach r in array array['anon', 'authenticated'] loop
    if has_function_privilege(r, f, 'EXECUTE') then
      en_trop := en_trop || r;
    end if;
  end loop;

  if array_length(en_trop, 1) is not null then
    raise exception
      'enregistrer_paiement est exécutable par : %. Elle écrit dans les '
      'tables financières et ne doit l''être que par le rôle de service.',
      array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits du paiement : conformes.';
end;
$$;

-- Les deux index uniques qui rendent le double paiement impossible.
--
-- Ils comptent autant que la fonction : ils tiennent même si le code
-- applicatif régresse, ce qui est exactement ce qui s'est produit une fois.
do $$
declare
  manquants text[] := '{}';
  i text;
begin
  foreach i in array array[
    'subscriptions_un_par_paiement_idx',
    'wallet_ledger_une_commission_par_paiement_idx'
  ] loop
    if not exists (
      select 1 from pg_indexes
      where schemaname = 'public' and indexname = i
    ) then
      manquants := manquants || i;
    end if;
  end loop;

  if array_length(manquants, 1) is not null then
    raise exception
      'Garde-fous d''unicité absents : %. Sans eux, une relivraison de '
      'webhook peut doubler un abonnement ou une commission.',
      array_to_string(manquants, ', ');
  end if;

  raise notice 'Unicité paiement → abonnement et paiement → commission : en place.';
end;
$$;
