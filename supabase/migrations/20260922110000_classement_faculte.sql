-- Le classement de sa faculté, sans ouvrir la lecture des profils.
--
-- La politique de `profiles` n'autorise que `id = auth.uid()` : un écran de
-- classement qui lit `profiles` directement ne voit donc **que sa propre
-- ligne**. C'est le cas de `app/(app)/classement/page.tsx`, qui interroge
-- `profiles` deux fois et n'obtient personne d'autre — l'écran est de toute
-- façon inatteignable, ce qui explique que cela n'ait pas été remarqué.
--
-- Ouvrir la lecture des profils serait hors de question : ils portent le
-- téléphone, l'empreinte de carte étudiante et le statut de vérification.
-- Une fonction `SECURITY DEFINER` étroite est la bonne réponse, à trois
-- conditions tirées des brèches passées :
--
--   1. **aucun identifiant d'utilisateur en paramètre** — c'est le motif qui
--      a coûté trois migrations sur `wallet_balance` puis une quatrième sur
--      `get_user_rank` ;
--   2. **aucun identifiant en sortie** : le classement dit « c'est toi » par
--      un booléen, il ne rend pas les UUID des autres ;
--   3. seules trois colonnes sortent — prénom, avatar, XP — et seulement
--      pour les membres de **sa propre** faculté.

create or replace function public.classement_faculte(limite integer default 20)
returns table (
  rang integer,
  prenom text,
  avatar_key text,
  xp_total integer,
  est_moi boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with ma_faculte as (
    select p.faculty_id
    from public.profiles p
    where p.id = auth.uid()
      and p.faculty_id is not null
  ),
  classes as (
    select
      row_number() over (
        order by p.xp_total desc, p.created_at asc
      )::integer as rang,
      p.id,
      p.first_name,
      p.avatar_key,
      p.xp_total
    from public.profiles p
    join ma_faculte f on f.faculty_id = p.faculty_id
    -- Un étudiant sans point n'est pas classé : le podium n'a pas à être
    -- rempli par des comptes inactifs.
    where p.xp_total > 0
  )
  select
    c.rang,
    c.first_name,
    c.avatar_key,
    c.xp_total,
    c.id = auth.uid()
  from classes c
  order by c.rang
  -- Borne dure : un client ne décide pas de rapatrier toute la faculté.
  limit greatest(1, least(coalesce(limite, 20), 100));
$$;

comment on function public.classement_faculte(integer) is
  'Classement de la faculté de l''appelant, par XP. Sans identifiant en '
  'paramètre ni en sortie : « c''est toi » se lit sur est_moi. Seuls prénom, '
  'avatar et XP sortent, et seulement pour sa propre faculté — la politique '
  'de profiles n''autorise que sa propre ligne, et les profils portent le '
  'téléphone et l''empreinte de carte étudiante.';

-- Sa propre position, même hors du haut de tableau.
create or replace function public.mon_rang_faculte()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  with ma_faculte as (
    select p.faculty_id
    from public.profiles p
    where p.id = auth.uid()
      and p.faculty_id is not null
  ),
  classes as (
    select
      p.id,
      row_number() over (
        order by p.xp_total desc, p.created_at asc
      )::integer as rang
    from public.profiles p
    join ma_faculte f on f.faculty_id = p.faculty_id
    where p.xp_total > 0
  )
  select c.rang from classes c where c.id = auth.uid();
$$;

comment on function public.mon_rang_faculte() is
  'Position de l''appelant dans sa faculté, NULL s''il n''a pas encore '
  'marqué de point ou n''a pas de faculté.';

-- Révoquer de PUBLIC **et** de anon avant d'accorder : révoquer un rôle
-- nommé ne retire pas le droit hérité de PUBLIC, et les privilèges par défaut
-- de Supabase accordent EXECUTE nominativement à anon comme à authenticated.
revoke all on function public.classement_faculte(integer) from public;
revoke all on function public.classement_faculte(integer) from anon;
grant execute on function public.classement_faculte(integer) to authenticated;

revoke all on function public.mon_rang_faculte() from public;
revoke all on function public.mon_rang_faculte() from anon;
grant execute on function public.mon_rang_faculte() to authenticated;
