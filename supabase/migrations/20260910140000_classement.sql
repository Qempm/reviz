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

-- Apostrophes doublées le 22 septembre 2026 : telles qu'écrites, elles
-- fermaient le littéral sur « d' » et la suite n'était pas du SQL valide.
-- `supabase db push` échouait donc sur ce fichier, et tout ce qui le suit.
-- Cette fonction est de toute façon remplacée par 20260922100100, qui lui
-- retire son paramètre et referme ses droits.
comment on function public.get_user_rank(uuid) is
  'Retourne la position d''un utilisateur dans le classement global (par XP). '
  'Retourne -1 si l''utilisateur n''est pas classé. '
  'Remplacée par get_user_rank() sans paramètre — voir 20260922100100.';

grant execute on function public.get_user_rank(uuid) to authenticated;
