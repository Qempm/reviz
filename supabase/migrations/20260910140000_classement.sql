-- Classement global par XP
-- Fonction pour obtenir la position d'un utilisateur dans le classement

create or replace function public.get_user_rank(target_user_id uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select coalesce(rank, -1)
  from (
    select
      p.id,
      row_number() over (order by p.xp_total desc, p.created_at asc) as rank
    from profiles p
    where p.xp_total > 0
  ) ranked
  where id = target_user_id;
$$;

comment on function public.get_user_rank(uuid) is
  'Retourne la position d'un utilisateur dans le classement global (par XP).
   Retourne -1 si l'utilisateur n'est pas classé.
   Fonctionnement : déterministe, lisible par tous les utilisateurs authentifiés.';

grant execute on function public.get_user_rank(uuid) to authenticated;
