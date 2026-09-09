-- Assertions sur le verrou de statut des cours.
--
-- Même intention que 20260909160000_verifie_droits.sql : ce qui protège la
-- base doit échouer au déploiement si quelqu'un le retire, et non se
-- découvrir en production. Un `create or replace function` suffit à effacer
-- un trigger de garde sans que rien ne le signale.

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.courses'::regclass
      and tgname = 'courses_protect_status'
      and not tgisinternal
  ) then
    raise exception
      'Le trigger courses_protect_status a disparu : un étudiant peut poser '
      'status = ''ready'' sur son propre cours.';
  end if;

  -- SECURITY DEFINER : la fonction doit pouvoir lire ce qu'il faut quelle
  -- que soit l'identité de l'appelant. Sans cela, le verrou tombe dès qu'un
  -- rôle n'a pas les droits.
  if not exists (
    select 1 from pg_proc
    where oid = 'public.protect_course_status()'::regprocedure
      and prosecdef
  ) then
    raise exception
      'protect_course_status() n''est plus SECURITY DEFINER.';
  end if;

  -- Le trigger doit être BEFORE UPDATE : en AFTER, l'écriture a déjà eu lieu
  -- et lever une exception coûterait un rollback à chaque tentative.
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.courses'::regclass
      and tgname = 'courses_protect_status'
      -- 2 = BEFORE, 16 = UPDATE dans tgtype.
      and (tgtype & 2) = 2
      and (tgtype & 16) = 16
  ) then
    raise exception
      'courses_protect_status n''est plus un BEFORE UPDATE.';
  end if;
end $$;

-- Le cours de démonstration doit rester lisible et rester une démonstration :
-- s'il perd `is_demo`, il devient une ligne orpheline invisible.
do $$
declare
  n integer;
begin
  select count(*) into n
  from public.courses
  where is_demo and owner_id is null and status = 'ready';

  if n = 0 then
    raise warning
      'Aucun cours de démonstration prêt : un compte neuf verra un écran '
      'vide. Voir 20260910100100_cours_demo_seed.sql.';
  end if;
end $$;
