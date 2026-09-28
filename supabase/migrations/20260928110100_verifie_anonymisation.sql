-- Fige les droits de l'anonymisation, et les trois raisons qui l'ont imposée.
--
-- Sixième migration d'assertion. Chacune n'attrape que ce qu'elle nomme.
--
-- Cette migration ne modifie rien.

do $$
declare
  f text := 'public.anonymiser_compte(uuid)';
  en_trop text[] := '{}';
  r text;
begin
  if to_regprocedure(f) is null then
    raise exception 'public.anonymiser_compte est absente.';
  end if;

  if not has_function_privilege('service_role', f, 'EXECUTE') then
    raise exception
      'Le rôle de service ne peut pas appeler anonymiser_compte : plus '
      'personne ne pourra supprimer son compte.';
  end if;

  -- Cette fonction vide un profil, détache des identités et bannit un
  -- compte. Un étudiant qui pourrait l'appeler effacerait celui d'un autre.
  foreach r in array array['anon', 'authenticated'] loop
    if has_function_privilege(r, f, 'EXECUTE') then
      en_trop := en_trop || r;
    end if;
  end loop;

  if array_length(en_trop, 1) is not null then
    raise exception
      'anonymiser_compte est exécutable par : %. Elle ne doit l''être que '
      'par le rôle de service, après que le serveur a vérifié qui demande.',
      array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits de l''anonymisation : conformes.';
end;
$$;

-- Pourquoi anonymiser et non supprimer.
--
-- Ces trois constats **sont** la justification de la fonction. S'ils
-- disparaissaient — trois clés étrangères passées en cascade, un trigger
-- retiré — une vraie suppression redeviendrait possible, et il faudrait
-- reconsidérer l'anonymisation plutôt que la garder par habitude. L'assertion
-- est donc là pour faire réfléchir, pas pour interdire : elle échoue si le
-- monde a changé.
do $$
declare
  restreintes text[] := '{}';
  t text;
begin
  foreach t in array array['payments', 'wallet_ledger', 'withdrawals'] loop
    if not exists (
      select 1
      from pg_constraint c
      join pg_class enfant on enfant.oid = c.conrelid
      join pg_class parent on parent.oid = c.confrelid
      where c.contype = 'f'
        and enfant.relname = t
        and parent.relname = 'profiles'
        -- 'r' = restrict
        and c.confdeltype = 'r'
    ) then
      restreintes := restreintes || t;
    end if;
  end loop;

  if array_length(restreintes, 1) is not null then
    raise exception
      'Ces tables ne bloquent plus la suppression d''un profil : %. Une '
      'vraie suppression est peut-être redevenue possible — relire '
      '20260928110000_anonymiser_compte.sql avant de garder l''anonymisation.',
      array_to_string(restreintes, ', ');
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'xp_events_no_delete' and not tgisinternal
  ) then
    raise exception
      'Le trigger xp_events_no_delete a disparu : le journal d''XP accepte '
      'désormais le DELETE, ce qui change la donne pour la suppression de '
      'compte.';
  end if;

  raise notice
    'Suppression de compte : toujours impossible (3 clés restrict + '
    'xp_events_no_delete). L''anonymisation reste la bonne réponse.';
end;
$$;
