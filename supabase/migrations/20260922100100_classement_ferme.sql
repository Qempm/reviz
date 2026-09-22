-- Referme le classement, et répare la migration qui ne pouvait pas passer.
--
-- `20260910140000_classement.sql` pose trois problèmes :
--
-- 1. **Elle ne s'applique pas.** Son `comment on function` contient une
--    apostrophe non échappée (« la position d'un utilisateur ») : le littéral
--    se ferme sur `d'` et la suite n'est pas du SQL valide. `supabase db push`
--    échoue dessus. Si elle n'est jamais passée, `get_user_rank` n'existe pas
--    en base et l'écran de classement est cassé en production.
--
-- 2. **Elle rouvre la brèche que trois migrations ont mis trois passes à
--    refermer** : `SECURITY DEFINER` avec un identifiant d'utilisateur en
--    paramètre, et pour seul droit `grant execute to authenticated` — ni
--    `revoke from public`, ni `revoke from anon`. La fonction lit `profiles`
--    en contournant la RLS, alors que la politique de `profiles` n'autorise
--    que la lecture de sa propre ligne. C'est le motif exact décrit dans
--    20260909130000_securise_fonctions.sql:1-14, et la règle énoncée dans
--    20260909150000_revoque_anon.sql:12-14 n'est pas suivie.
--
-- 3. Elle annonce `-1` pour un non-classé, mais le `coalesce(rank, -1)` est
--    à l'intérieur du `select` : si l'utilisateur n'est pas dans la
--    sous-requête (`xp_total > 0`), le `where` ne renvoie **aucune ligne** et
--    la fonction retourne NULL. Et elle est VOLATILE par défaut alors que son
--    corps est un pur `select`.
--
-- Le paramètre disparaît, comme pour `wallet_balance` en
-- 20260909130000:18-30 : le seul appelant passait déjà `user.id`, donc
-- `auth.uid()` suffit et il n'y a plus rien à divulguer.

-- `create or replace` ne peut pas changer une signature. `if exists` parce
-- que la migration d'origine a pu ne jamais s'appliquer.
drop function if exists public.get_user_rank(uuid);

create or replace function public.get_user_rank()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select position
  from (
    select
      p.id,
      row_number() over (order by p.xp_total desc, p.created_at asc) as position
    from public.profiles p
    where p.xp_total > 0
  ) classes
  where classes.id = auth.uid();
$$;

comment on function public.get_user_rank() is
  'Position de l''appelant au classement global par XP, NULL s''il n''a pas '
  'encore marqué de point. Sans paramètre, volontairement : une fonction '
  'SECURITY DEFINER qui prend un identifiant de cible divulgue la ligne de '
  'n''importe qui.';

-- Révoquer de PUBLIC **et** de anon avant d'accorder : révoquer un rôle
-- nommé ne retire pas le droit hérité de PUBLIC, et les privilèges par défaut
-- de Supabase accordent EXECUTE nominativement à anon.
revoke all on function public.get_user_rank() from public;
revoke all on function public.get_user_rank() from anon;
grant execute on function public.get_user_rank() to authenticated;
