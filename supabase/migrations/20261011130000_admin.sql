-- L'espace administrateur (11 octobre 2026).
--
-- Le propriétaire voit sur `/admin` les téléchargements, les comptes et
-- l'activité, et les paiements en direct. Tout est lu par le rôle de service,
-- depuis le serveur, après vérification de son e-mail (`ADMIN_EMAILS`) : les
-- fonctions ci-dessous ne sont ouvertes à aucun autre rôle, et aucune
-- politique RLS n'élargit la lecture des paiements.

-- 1. Les clics sur « Télécharger » ------------------------------------------
--
-- La route `/telecharger` en écrit une ligne avant de rediriger vers l'APK.
-- Ni adresse IP ni identifiant : un jour, d'où vient le clic, et la famille
-- d'appareil.

create table public.telechargements (
  id bigint generated always as identity primary key,
  jour date not null default current_date,
  source text not null default 'autre' check (source in ('accueil', 'app', 'autre')),
  appareil text not null default 'autre' check (appareil in ('android', 'ios', 'ordinateur', 'autre')),
  created_at timestamptz not null default now()
);

create index telechargements_jour_idx on public.telechargements (jour desc);

alter table public.telechargements enable row level security;
-- Aucune politique : fermée au client, écrite et lue par le serveur.

-- 2. Le tableau de bord -------------------------------------------------------

create or replace function public.admin_tableau()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with vivants as (
    -- Un compte supprimé est anonymisé, pas effacé : on l'écarte.
    select p.id, p.created_at, p.verification_status
    from public.profiles p
    join auth.users u on u.id = p.id
    where u.email is null or u.email not like '%@compte-supprime.invalid'
  ),
  paye as (
    select amount_fcfa, created_at from public.payments where status = 'success'
  )
  select jsonb_build_object(
    'comptes', (select count(*) from vivants),
    'verifies', (select count(*) from vivants where verification_status = 'verified'),
    'enAttenteDeVerification', (select count(*) from vivants where verification_status = 'pending'),
    'nouveaux', jsonb_build_object(
      'jour', (select count(*) from vivants where created_at >= date_trunc('day', now())),
      'semaine', (select count(*) from vivants where created_at >= now() - interval '7 days'),
      'mois', (select count(*) from vivants where created_at >= now() - interval '30 days')
    ),
    -- Actif : a répondu à au moins une question ce jour-là.
    'actifs', jsonb_build_object(
      'jour', (select count(distinct user_id) from public.daily_activity where day = current_date),
      'semaine', (select count(distinct user_id) from public.daily_activity where day > current_date - 7),
      'mois', (select count(distinct user_id) from public.daily_activity where day > current_date - 30)
    ),
    'appareils', (
      select coalesce(jsonb_object_agg(plateforme, n), '{}'::jsonb)
      from (select plateforme, count(*) as n from public.appareils group by plateforme) a
    ),
    'cours', (select count(*) from public.courses),
    'coursPrets', (select count(*) from public.courses where status = 'ready'),
    'corrections', (select count(*) from public.corrections),
    'tuteur', (select count(*) from public.tuteur_sessions),
    'packsActifs', (
      select coalesce(jsonb_object_agg(pack_code, n), '{}'::jsonb)
      from (
        select pack_code, count(distinct user_id) as n
        from public.subscriptions
        where starts_at <= now() and ends_at > now()
        group by pack_code
      ) s
    ),
    'encaisse', jsonb_build_object(
      'jour', (select coalesce(sum(amount_fcfa), 0) from paye where created_at >= date_trunc('day', now())),
      'semaine', (select coalesce(sum(amount_fcfa), 0) from paye where created_at >= now() - interval '7 days'),
      'mois', (select coalesce(sum(amount_fcfa), 0) from paye where created_at >= now() - interval '30 days'),
      'total', (select coalesce(sum(amount_fcfa), 0) from paye)
    ),
    'paiements', jsonb_build_object(
      'reussis', (select count(*) from public.payments where status = 'success'),
      'enAttente', (select count(*) from public.payments where status = 'pending'),
      'echoues', (select count(*) from public.payments where status = 'failed')
    ),
    'coutIa30j', (
      select coalesce(sum(cost_usd_estimate), 0)
      from public.ai_usage
      where created_at >= now() - interval '30 days'
    ),
    'telechargementsSite', jsonb_build_object(
      'total', (select count(*) from public.telechargements),
      'semaine', (select count(*) from public.telechargements where jour > current_date - 7)
    )
  )
$$;

comment on function public.admin_tableau() is
  'Les chiffres de l''espace administrateur. Rôle de service seulement.';

-- 3. Les derniers paiements ---------------------------------------------------
--
-- Le numéro sort en clair d'ici, vers le serveur seulement : la route
-- `/api/admin/flux` le masque (`lib/admin/statistiques.ts`) avant de
-- l'envoyer au navigateur.

create or replace function public.admin_paiements(limite integer default 50)
returns table (
  id uuid,
  cree_le timestamptz,
  prenom text,
  pack text,
  montant integer,
  operateur text,
  statut text,
  telephone text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    pay.id,
    pay.created_at,
    pr.first_name,
    pay.pack_code::text,
    pay.amount_fcfa,
    pay.operator,
    pay.status::text,
    pay.phone
  from public.payments pay
  left join public.profiles pr on pr.id = pay.user_id
  order by pay.created_at desc
  limit least(greatest(coalesce(limite, 50), 1), 200)
$$;

comment on function public.admin_paiements(integer) is
  'Les derniers paiements pour l''espace administrateur. Rôle de service seulement.';

revoke all on function public.admin_tableau() from public;
revoke all on function public.admin_tableau() from anon;
revoke all on function public.admin_tableau() from authenticated;
grant execute on function public.admin_tableau() to service_role;

revoke all on function public.admin_paiements(integer) from public;
revoke all on function public.admin_paiements(integer) from anon;
revoke all on function public.admin_paiements(integer) from authenticated;
grant execute on function public.admin_paiements(integer) to service_role;
