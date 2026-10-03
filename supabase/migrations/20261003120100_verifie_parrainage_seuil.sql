-- Fige le seuil de parrainage et les droits de `enregistrer_paiement`,
-- redéfinie par `20261003120000_parrainage_seuil_xp.sql`.
--
-- Même motif que `20260922120100_verifie_paiement.sql` : une fonction
-- redéfinie peut perdre ses droits ou son garde-fou sans bruit. Ces
-- assertions le disent tout de suite. Cette migration ne modifie rien.

do $$
declare
  f text := 'public.enregistrer_paiement(text, text, public.payment_status, '
            'jsonb, timestamptz, timestamptz, integer, uuid, integer, '
            'numeric)';
  r text;
begin
  if to_regprocedure('public.seuil_xp_parrainage()') is null then
    raise exception 'public.seuil_xp_parrainage() est absente.';
  end if;

  if public.seuil_xp_parrainage() <> 3000 then
    raise exception
      'Le seuil de parrainage vaut % au lieu de 3000 : il doit rester égal à '
      'SEUIL_XP_PARRAINAGE (lib/payments/commission.ts).',
      public.seuil_xp_parrainage();
  end if;

  if to_regprocedure(f) is null then
    raise exception 'public.enregistrer_paiement est absente.';
  end if;

  if pg_get_functiondef(to_regprocedure(f)) not like '%seuil_xp_parrainage()%' then
    raise exception
      'enregistrer_paiement ne vérifie plus le seuil de 3 000 XP du parrain.';
  end if;

  if not has_function_privilege('service_role', f, 'EXECUTE') then
    raise exception
      'Le rôle de service ne peut pas appeler enregistrer_paiement : le '
      'webhook ne pourra plus rien enregistrer.';
  end if;

  foreach r in array array['anon', 'authenticated'] loop
    if has_function_privilege(r, f, 'EXECUTE') then
      raise exception
        'enregistrer_paiement est exécutable par % : elle écrit dans les '
        'tables financières et ne doit l''être que par le rôle de service.', r;
    end if;
  end loop;

  raise notice 'Seuil de parrainage (3 000 XP) et droits du paiement : conformes.';
end;
$$;
