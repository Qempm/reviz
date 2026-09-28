-- Fige les droits des deux fonctions de la correction.
--
-- Cinquième migration de ce genre. Chacune n'attrape que ce qu'elle nomme —
-- c'est la limite reconnue de l'exercice, et la raison de l'étendre à chaque
-- fonction sensible plutôt que d'espérer qu'une assertion antérieure couvre
-- la nouvelle.
--
-- Cette migration ne modifie rien.

do $$
declare
  requises text[] := array[
    'public.claim_job(uuid, interval)',
    'public.consommer_correction(uuid)'
  ];
  absentes text[] := '{}';
  en_trop text[] := '{}';
  f text;
  r text;
begin
  foreach f in array requises loop
    if to_regprocedure(f) is null then
      absentes := absentes || (f || ' (absente)');
      continue;
    end if;

    if not has_function_privilege('service_role', f, 'EXECUTE') then
      absentes := absentes || (f || ' → service_role manquant');
    end if;

    -- `claim_job` puise dans la file ; `consommer_correction` touche à un
    -- accès payé. Un étudiant qui pourrait les appeler se relancerait des
    -- traitements à volonté, ou s'offrirait des corrections.
    foreach r in array array['anon', 'authenticated'] loop
      if has_function_privilege(r, f, 'EXECUTE') then
        en_trop := en_trop || (f || ' → ' || r);
      end if;
    end loop;
  end loop;

  if array_length(absentes, 1) is not null then
    raise exception 'Droits manquants : %', array_to_string(absentes, ', ');
  end if;
  if array_length(en_trop, 1) is not null then
    raise exception 'Droits en trop : %', array_to_string(en_trop, ', ');
  end if;

  raise notice 'Droits de la correction : conformes.';
end;
$$;

-- Le décompte ne doit jamais passer sous zéro.
--
-- La contrainte existe (`corrections_left >= 0`), mais elle est portée par la
-- table et non par la fonction : cette assertion vérifie qu'elle est toujours
-- là, puisque c'est elle qui rattraperait un bogue de `consommer_correction`.
do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    where t.relname = 'subscriptions'
      and pg_get_constraintdef(c.oid) ilike '%corrections_left >= 0%'
  ) then
    raise exception
      'La contrainte corrections_left >= 0 a disparu : un décompte de trop '
      'passerait en négatif sans que rien ne le signale.';
  end if;

  raise notice 'Plancher du crédit de correction : en place.';
end;
$$;
