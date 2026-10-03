-- Fige la suspension des commissions et les droits de `enregistrer_paiement`,
-- redéfinie par `20261003140000_commissions_suspendues.sql`.
--
-- Même motif que `20261003120100_verifie_parrainage_seuil.sql`. Cette
-- migration ne modifie rien. Le jour où les commissions reprennent, c'est la
-- valeur attendue ici qu'on change, en même temps que l'interrupteur.

do $$
declare
  f text := 'public.enregistrer_paiement(text, text, public.payment_status, '
            'jsonb, timestamptz, timestamptz, integer, uuid, integer, '
            'numeric)';
  r text;
begin
  if to_regprocedure('public.commissions_actives()') is null then
    raise exception 'public.commissions_actives() est absente.';
  end if;

  if public.commissions_actives() then
    raise exception
      'Les commissions sont actives : elles doivent rester suspendues, comme '
      'COMMISSIONS_ACTIVES (lib/payments/commission.ts).';
  end if;

  if pg_get_functiondef(to_regprocedure(f)) not like '%commissions_actives()%' then
    raise exception
      'enregistrer_paiement ne consulte plus l''interrupteur des commissions.';
  end if;

  if pg_get_functiondef(to_regprocedure(f)) not like '%seuil_xp_parrainage()%' then
    raise exception
      'enregistrer_paiement ne vérifie plus le seuil de 3 000 XP du parrain.';
  end if;

  if not has_function_privilege('service_role', f, 'EXECUTE') then
    raise exception
      'Le rôle de service ne peut pas appeler enregistrer_paiement.';
  end if;

  foreach r in array array['anon', 'authenticated'] loop
    if has_function_privilege(r, f, 'EXECUTE') then
      raise exception
        'enregistrer_paiement est exécutable par % : elle ne doit l''être que '
        'par le rôle de service.', r;
    end if;
  end loop;

  raise notice 'Commissions suspendues et droits du paiement : conformes.';
end;
$$;
