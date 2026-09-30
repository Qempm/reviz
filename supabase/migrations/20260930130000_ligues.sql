-- Les ligues de la semaine, à la manière de Duolingo.
--
-- Chaque semaine (du lundi 00:00 UTC au dimanche soir), un étudiant qui gagne
-- de l'XP entre dans un groupe de trente au plus, de sa division. À la
-- clôture, les sept premiers montent, les cinq derniers descendent. Six
-- divisions : Bronze, Argent, Or, Saphir, Rubis, Diamant.
--
-- Trois choix, et leur raison :
--
--   * **la division vit dans une table à part** (`ligue_joueurs`), et non
--     dans `profiles` : un étudiant peut mettre à jour son profil, il ne doit
--     pas pouvoir se promouvoir ;
--   * **on n'entre dans une ligue qu'en gagnant de l'XP** : un compte
--     inactif ne remplit pas un groupe, comme au classement de faculté ;
--   * **la clôture est paresseuse** : la tâche du soir ne tourne qu'une fois
--     par jour (22:00 UTC, dimanche compris, donc avant la fin de la
--     semaine). La première XP de la semaine suivante clôt donc la
--     précédente avant de placer l'étudiant — sans quoi il entrerait dans un
--     groupe de son ancienne division. La tâche du soir reste le filet.
--
-- Aucune lecture directe : les trois tables n'ont pas de politique, tout
-- passe par `ma_ligue()`, qui ne rend ni identifiant ni téléphone — le même
-- contrat que `classement_faculte()`.

create table public.ligue_joueurs (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  division smallint not null default 1 check (division between 1 and 6),
  updated_at timestamptz not null default now()
);

create table public.ligue_groupes (
  id uuid primary key default gen_random_uuid(),
  -- Le lundi de la semaine, en UTC.
  semaine date not null,
  division smallint not null check (division between 1 and 6),
  taille integer not null default 0 check (taille between 0 and 30),
  cloture boolean not null default false,
  created_at timestamptz not null default now()
);

create index ligue_groupes_ouverts_idx
  on public.ligue_groupes (semaine, division, created_at)
  where taille < 30;

create index ligue_groupes_a_clore_idx
  on public.ligue_groupes (semaine)
  where not cloture;

create table public.ligue_membres (
  semaine date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  groupe_id uuid not null references public.ligue_groupes (id) on delete cascade,
  xp integer not null default 0,
  -- Départage : à XP égale, celui qui l'a atteinte le premier passe devant.
  derniere_xp timestamptz not null default now(),
  rang_final integer,
  issue text check (issue in ('monte', 'reste', 'descend')),
  primary key (semaine, user_id)
);

create index ligue_membres_groupe_idx on public.ligue_membres (groupe_id);
create index ligue_membres_user_idx on public.ligue_membres (user_id, semaine desc);

alter table public.ligue_joueurs enable row level security;
alter table public.ligue_groupes enable row level security;
alter table public.ligue_membres enable row level security;

revoke all on public.ligue_joueurs from public, anon, authenticated;
revoke all on public.ligue_groupes from public, anon, authenticated;
revoke all on public.ligue_membres from public, anon, authenticated;

comment on table public.ligue_membres is
  'Une ligne par étudiant et par semaine où il a gagné de l''XP. Lue par '
  'ma_ligue() seulement.';

-- Le lundi (UTC) de la semaine d'un instant.
create or replace function public.ligue_lundi(t timestamptz)
returns date
language sql
immutable
set search_path = public
as $$
  select date_trunc('week', t at time zone 'utc')::date;
$$;

-- Clôt les semaines passées : rang final, montée, descente, nouvelle
-- division. Idempotente, et sérialisée par un verrou : la tâche du soir et
-- la première XP d'un lundi peuvent l'appeler en même temps.
create or replace function public.cloturer_ligues()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  g record;
  closes integer := 0;
  lundi date := public.ligue_lundi(now());
begin
  perform pg_advisory_xact_lock(hashtext('cloturer_ligues'));

  for g in
    select id, division
    from public.ligue_groupes
    where not cloture and semaine < lundi
    order by semaine, created_at
  loop
    with classes as (
      select
        m.user_id,
        row_number() over (order by m.xp desc, m.derniere_xp asc)::integer as rang,
        count(*) over ()::integer as n,
        m.xp
      from public.ligue_membres m
      where m.groupe_id = g.id
    ),
    issues as (
      select
        c.user_id,
        c.rang,
        case
          -- Monter demande d'avoir gagné quelque chose : un ajustement
          -- négatif peut ramener à zéro.
          when g.division < 6 and c.rang <= 7 and c.xp > 0 then 'monte'
          -- Dans un petit groupe, les zones se chevaucheraient : la montée
          -- l'emporte, et on ne descend que hors des sept premiers.
          when g.division > 1 and c.rang > greatest(7, c.n - 5) then 'descend'
          else 'reste'
        end as issue
      from classes c
    )
    update public.ligue_membres m
    set rang_final = i.rang,
        issue = i.issue
    from issues i
    where m.groupe_id = g.id and m.user_id = i.user_id;

    insert into public.ligue_joueurs as j (user_id, division, updated_at)
    select
      m.user_id,
      greatest(1, least(6, g.division + case m.issue
        when 'monte' then 1
        when 'descend' then -1
        else 0
      end)),
      now()
    from public.ligue_membres m
    where m.groupe_id = g.id
    on conflict (user_id) do update
      set division = excluded.division,
          updated_at = excluded.updated_at;

    update public.ligue_groupes set cloture = true where id = g.id;
    closes := closes + 1;
  end loop;

  return closes;
end;
$$;

comment on function public.cloturer_ligues() is
  'Clôt les groupes des semaines passées (7 montent, 5 descendent) et met à '
  'jour les divisions. Idempotente ; appelée par la tâche du soir et par la '
  'première XP de chaque semaine.';

-- Chaque XP compte pour la ligue de la semaine.
create or replace function public.ligue_suivre_xp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  semaine_xp date := public.ligue_lundi(new.created_at);
  ma_division smallint;
  groupe uuid;
begin
  update public.ligue_membres
  set xp = xp + new.amount,
      derniere_xp = new.created_at
  where semaine = semaine_xp and user_id = new.user_id;

  if found or new.amount <= 0 then
    return new;
  end if;

  -- Une XP antidatée (un ajustement du serveur) ne rouvre pas une semaine
  -- passée.
  if semaine_xp <> public.ligue_lundi(now()) then
    return new;
  end if;

  -- Première XP de la semaine : clore la précédente d'abord, pour entrer
  -- dans un groupe de la bonne division.
  perform public.cloturer_ligues();

  select division into ma_division
  from public.ligue_joueurs
  where user_id = new.user_id;
  ma_division := coalesce(ma_division, 1);

  select id into groupe
  from public.ligue_groupes
  where semaine = semaine_xp and division = ma_division and taille < 30
    and not cloture
  order by created_at
  limit 1
  for update skip locked;

  if groupe is null then
    insert into public.ligue_groupes (semaine, division)
    values (semaine_xp, ma_division)
    returning id into groupe;
  end if;

  update public.ligue_groupes set taille = taille + 1 where id = groupe;

  insert into public.ligue_membres (semaine, user_id, groupe_id, xp, derniere_xp)
  values (semaine_xp, new.user_id, groupe, new.amount, new.created_at);

  return new;
exception
  -- Une ligue en panne ne doit jamais empêcher de gagner des points : l'XP
  -- est le cœur, la ligue n'en est que l'affichage.
  when others then
    raise warning 'ligue_suivre_xp : % (%)', sqlerrm, sqlstate;
    return new;
end;
$$;

create trigger xp_events_ligue
  after insert on public.xp_events
  for each row execute function public.ligue_suivre_xp();

-- Ce que voit l'étudiant : sa division, son groupe, et l'issue de la
-- semaine précédente. Sans identifiant en paramètre ni en sortie ; prénom,
-- avatar et XP seulement ; les comptes supprimés n'apparaissent plus.
create or replace function public.ma_ligue()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with moi as (
    select auth.uid() as id, public.ligue_lundi(now()) as lundi
  ),
  mon_groupe as (
    select m.groupe_id, g.division
    from public.ligue_membres m
    join public.ligue_groupes g on g.id = m.groupe_id
    join moi on m.user_id = moi.id and m.semaine = moi.lundi
  ),
  classes as (
    select
      row_number() over (order by m.xp desc, m.derniere_xp asc)::integer as rang,
      p.first_name,
      p.avatar_key,
      m.xp,
      m.user_id = (select id from moi) as est_moi
    from public.ligue_membres m
    join mon_groupe mg on mg.groupe_id = m.groupe_id
    join public.profiles p on p.id = m.user_id
    where p.referral_code not like 'SUPPR-%'
  ),
  derniere as (
    select m.semaine, m.rang_final, m.issue, g.division
    from public.ligue_membres m
    join public.ligue_groupes g on g.id = m.groupe_id
    join moi on m.user_id = moi.id
    where m.issue is not null
    order by m.semaine desc
    limit 1
  )
  select jsonb_build_object(
    'division', coalesce(
      (select division from mon_groupe),
      (select j.division from public.ligue_joueurs j, moi where j.user_id = moi.id),
      1
    ),
    'semaine', (select lundi from moi),
    'fin', ((select lundi from moi) + 7)::timestamp at time zone 'utc',
    'montee', 7,
    'descente', 5,
    'membres', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'rang', c.rang,
          'prenom', c.first_name,
          'avatar', c.avatar_key,
          'xp', c.xp,
          'moi', c.est_moi
        ) order by c.rang)
       from classes c),
      '[]'::jsonb
    ),
    'derniere', (
      select jsonb_build_object(
        'semaine', d.semaine,
        'rang', d.rang_final,
        'issue', d.issue,
        'division', d.division
      )
      from derniere d
    )
  )
  where auth.uid() is not null;
$$;

comment on function public.ma_ligue() is
  'La ligue de la semaine de l''appelant : division, membres de son groupe '
  '(prénom, avatar, XP, rang, est-ce moi), et l''issue de la dernière '
  'semaine close. Sans identifiant en paramètre ni en sortie.';

revoke all on function public.ligue_lundi(timestamptz) from public, anon;
grant execute on function public.ligue_lundi(timestamptz) to authenticated, service_role;

revoke all on function public.cloturer_ligues() from public, anon, authenticated;
grant execute on function public.cloturer_ligues() to service_role;

revoke all on function public.ligue_suivre_xp() from public, anon, authenticated;

revoke all on function public.ma_ligue() from public, anon;
grant execute on function public.ma_ligue() to authenticated;
