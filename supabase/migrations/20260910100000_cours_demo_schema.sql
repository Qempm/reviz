-- Rend possible un cours sans propriétaire, visible de tous.
--
-- `courses.owner_id` était `not null references profiles`, et
-- `can_read_course()` n'autorise que le propriétaire ou sa faculté. Un cours
-- semé par migration n'a donc aucun propriétaire possible : l'insertion
-- échouait, et même insérée la ligne aurait été invisible de tout le monde.
--
-- Un cours de démonstration sert à deux choses : montrer le produit à un
-- étudiant qui n'a encore rien déposé, et permettre de construire le parcours
-- de révision avant que l'IA ne génère quoi que ce soit.

alter table public.courses
  alter column owner_id drop not null;

alter table public.courses
  add column is_demo boolean not null default false;

-- Un cours est soit possédé, soit de démonstration. Jamais ni l'un ni l'autre :
-- une ligne orpheline non marquée serait invisible et impossible à rattacher.
alter table public.courses
  add constraint courses_proprietaire_ou_demo
  check (owner_id is not null or is_demo);

comment on column public.courses.is_demo is
  'Cours de démonstration : sans propriétaire, lisible par tout étudiant '
  'connecté quelle que soit sa faculté. Sert de vitrine et de jeu d''essai '
  'avant que l''IA ne produise du contenu réel.';

-- Les cours de démonstration ne se cherchent pas par empreinte : ils ne
-- participent pas au cache de la règle métier 4.
create index courses_demo_idx on public.courses (is_demo) where is_demo;

-- Visibilité ----------------------------------------------------------------

create or replace function public.can_read_course(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.courses c
    left join public.subjects s on s.id = c.subject_id
    left join public.profiles o on o.id = c.owner_id
    where c.id = target
      and (
        -- Un cours de démonstration est ouvert à tout étudiant connecté.
        c.is_demo
        or c.owner_id = auth.uid()
        or (
          c.shared_with_faculty
          -- La faculté du cours vient de sa matière ; à défaut, de son
          -- propriétaire.
          and coalesce(s.faculty_id, o.faculty_id) is not distinct from
              public.current_faculty_id()
          and public.current_faculty_id() is not null
        )
      )
  );
$$;

-- Le remplacement de la fonction remet les droits par défaut de Supabase :
-- il faut refermer, comme l'explique 20260909150000_revoque_anon.sql.
revoke all on function public.can_read_course(uuid) from public;
revoke all on function public.can_read_course(uuid) from anon;
grant execute on function public.can_read_course(uuid) to authenticated;

-- La politique d'insertion reste inchangée et suffit : elle exige
-- `owner_id = auth.uid()`, donc un client ne peut pas se fabriquer un cours
-- de démonstration.
