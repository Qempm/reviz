-- Les notifications de l'étudiant : un centre dans l'application, et le push.
--
-- Arbitrage du 1er octobre 2026. Jusque-là, un cours prêt, une copie
-- corrigée, un paiement confirmé n'atteignaient l'étudiant que s'il restait
-- sur l'écran qui interrogeait le serveur. Désormais, **chaque événement
-- laisse une ligne** dans `notifications` :
--
--  - le centre de notifications de l'application la lit (RLS) — il marche
--    partout, web et iPhone compris ;
--  - le serveur l'envoie ensuite en push (`lib/notifications/envoyer.ts`),
--    selon les préférences de l'étudiant, et pose `push_sent_at`.
--
-- Les lignes naissent ici, dans des déclencheurs, et non dans le code des
-- routes : un statut passé à la main en base (un retrait payé, aujourd'hui)
-- ou par une fonction SQL (la clôture des ligues) prévient l'étudiant comme
-- les autres. Les déclencheurs n'appellent rien sur le réseau : ils insèrent,
-- c'est tout.

-- ---------------------------------------------------------------- Tables

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in (
    'cours_pret', 'cours_echoue',
    'correction_prete', 'correction_illisible', 'correction_echouee',
    'paiement_reussi', 'paiement_echoue', 'commission_recue',
    'retrait_paye', 'retrait_refuse',
    'carte_verifiee', 'carte_refusee',
    'ligue_cloturee'
  )),
  -- L'objet concerné (cours, correction, paiement…) ; nul quand il n'y en a
  -- pas d'autre que le profil lui-même (la carte).
  reference_id uuid,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.notifications is
  'Ce qui est arrivé à l''étudiant, une ligne par événement. Écrite par des '
  'déclencheurs, lue par le centre de notifications, envoyée en push par '
  'lib/notifications/envoyer.ts.';

-- Un événement rejoué (un webhook reçu deux fois, un traitement repris) ne
-- crée pas de doublon. Les lignes sans référence (la carte) ne sont pas
-- concernées : NULL n'est jamais égal à NULL, et leur déclencheur ne réagit
-- qu'à un changement d'état.
create unique index notifications_unique_idx
  on public.notifications (user_id, kind, reference_id);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

-- La passe de rattrapage du cron ne lit que ce qui n'est pas encore parti.
create index notifications_push_en_attente_idx
  on public.notifications (created_at)
  where push_sent_at is null;

create table public.appareils (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  plateforme text not null check (plateforme in ('android', 'ios')),
  created_at timestamptz not null default now(),
  vu_le timestamptz not null default now()
);

comment on table public.appareils is
  'Jetons de push (FCM), un par téléphone. Écrits et lus par le serveur '
  'seulement : aucune politique client.';

create index appareils_user_idx on public.appareils (user_id);

-- Préférences de push par catégorie : {"cours":true,"argent":true,
-- "compte":true,"ligue":true}. Une clé absente vaut « oui ». Non verrouillée
-- par protect_profile_columns() : l'étudiant l'écrit lui-même (RLS).
alter table public.profiles
  add column notifications jsonb not null default '{}'::jsonb;

-- ------------------------------------------------------------------- RLS

alter table public.notifications enable row level security;
alter table public.appareils enable row level security;

create policy notifications_select_own
  on public.notifications for select
  using (user_id = auth.uid());

-- Pas d'insert, d'update ni de delete pour le client : marquer comme lu passe
-- par la fonction ci-dessous, qui ne touche que `read_at`.

create or replace function public.marquer_notifications_lues(ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if auth.uid() is null then
    return 0;
  end if;

  update public.notifications
  set read_at = now()
  where user_id = auth.uid()
    and read_at is null
    and (ids is null or id = any (ids));

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.marquer_notifications_lues(uuid[]) from public;
grant execute on function public.marquer_notifications_lues(uuid[]) to authenticated;

-- -------------------------------------------------------------- Écriture

create or replace function public.notifier(
  p_user uuid,
  p_kind text,
  p_reference uuid,
  p_data jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (user_id, kind, reference_id, data)
  values (p_user, p_kind, p_reference, coalesce(p_data, '{}'::jsonb))
  on conflict (user_id, kind, reference_id) do nothing;
$$;

revoke all on function public.notifier(uuid, text, uuid, jsonb) from public;

-- --------------------------------------------------------- Déclencheurs

-- Un cours prêt ou en échec, pour son propriétaire. Les démonstrations n'en
-- ont pas.
create or replace function public.notifier_cours()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status
     or new.owner_id is null or new.is_demo then
    return new;
  end if;

  if new.status = 'ready' then
    perform public.notifier(new.owner_id, 'cours_pret', new.id,
      jsonb_build_object('titre', new.title));
  elsif new.status = 'failed' then
    perform public.notifier(new.owner_id, 'cours_echoue', new.id,
      jsonb_build_object('titre', new.title));
  end if;
  return new;
end;
$$;

create trigger courses_notifier
  after update of status on public.courses
  for each row execute function public.notifier_cours();

-- Une copie corrigée, illisible ou en échec.
create or replace function public.notifier_correction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'ready' then
    perform public.notifier(new.user_id, 'correction_prete', new.id,
      jsonb_build_object('note', new.grade, 'bareme', new.max_grade));
  elsif new.status = 'failed' then
    if coalesce((new.feedback ->> 'illisible')::boolean, false) then
      perform public.notifier(new.user_id, 'correction_illisible', new.id, '{}'::jsonb);
    else
      perform public.notifier(new.user_id, 'correction_echouee', new.id, '{}'::jsonb);
    end if;
  end if;
  return new;
end;
$$;

create trigger corrections_notifier
  after update of status on public.corrections
  for each row execute function public.notifier_correction();

-- La carte étudiante, vérifiée ou refusée.
create or replace function public.notifier_carte()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verification_status is not distinct from old.verification_status then
    return new;
  end if;

  if new.verification_status = 'verified' then
    perform public.notifier(new.id, 'carte_verifiee', null, '{}'::jsonb);
  elsif new.verification_status = 'rejected' then
    perform public.notifier(new.id, 'carte_refusee', null, '{}'::jsonb);
  end if;
  return new;
end;
$$;

create trigger profiles_notifier_carte
  after update of verification_status on public.profiles
  for each row execute function public.notifier_carte();

-- Un paiement confirmé ou refusé.
create or replace function public.notifier_paiement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'success' then
    perform public.notifier(new.user_id, 'paiement_reussi', new.id,
      jsonb_build_object('montant', new.amount_fcfa, 'pack', new.pack_code));
  elsif new.status = 'failed' then
    perform public.notifier(new.user_id, 'paiement_echoue', new.id,
      jsonb_build_object('montant', new.amount_fcfa, 'pack', new.pack_code));
  end if;
  return new;
end;
$$;

create trigger payments_notifier
  after update of status on public.payments
  for each row execute function public.notifier_paiement();

-- Une commission de parrainage, à chaque écriture du grand livre.
create or replace function public.notifier_commission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type = 'referral_commission' and new.amount_fcfa > 0 then
    perform public.notifier(new.user_id, 'commission_recue', new.id,
      jsonb_build_object('montant', new.amount_fcfa));
  end if;
  return new;
end;
$$;

create trigger wallet_ledger_notifier
  after insert on public.wallet_ledger
  for each row execute function public.notifier_commission();

-- Un retrait payé ou refusé — passé à la main en base, aujourd'hui.
create or replace function public.notifier_retrait()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'paid' then
    perform public.notifier(new.user_id, 'retrait_paye', new.id,
      jsonb_build_object('montant', new.amount_fcfa, 'operateur', new.operator));
  elsif new.status = 'rejected' then
    perform public.notifier(new.user_id, 'retrait_refuse', new.id,
      jsonb_build_object('montant', new.amount_fcfa, 'motif', new.failure_reason));
  end if;
  return new;
end;
$$;

create trigger withdrawals_notifier
  after update of status on public.withdrawals
  for each row execute function public.notifier_retrait();

-- La ligue de la semaine, à sa clôture (`cloturer_ligues()` pose `issue`).
-- Seulement pour qui a joué : prévenir chaque dimanche un étudiant inactif
-- qu'il « reste » ne lui apprendrait rien et finirait par le faire couper
-- toutes les notifications.
create or replace function public.notifier_ligue()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  division_semaine smallint;
begin
  if new.issue is null or old.issue is not null or new.xp <= 0 then
    return new;
  end if;

  select g.division into division_semaine
  from public.ligue_groupes g
  where g.id = new.groupe_id;

  perform public.notifier(new.user_id, 'ligue_cloturee', new.groupe_id,
    jsonb_build_object(
      'issue', new.issue,
      'rang', new.rang_final,
      'division', greatest(1, least(6, coalesce(division_semaine, 1) +
        case new.issue when 'monte' then 1 when 'descend' then -1 else 0 end))
    ));
  return new;
end;
$$;

create trigger ligue_membres_notifier
  after update of issue on public.ligue_membres
  for each row execute function public.notifier_ligue();

-- -------------------------------------------------------------- Le push

-- Réserve les notifications à pousser : pose `push_sent_at` et les rend, en
-- une instruction. Deux passes simultanées (une fin de job et le cron) ne se
-- partagent jamais une ligne — `skip locked` —, donc aucun push n'arrive en
-- double. Une ligne réservée dont l'envoi échoue n'est pas reprise : le
-- centre de notifications l'a toujours.
create or replace function public.reserver_notifications_a_pousser(
  p_limite integer default 100,
  p_user uuid default null
)
returns setof public.notifications
language sql
security definer
set search_path = public
as $$
  update public.notifications n
  set push_sent_at = now()
  where n.id in (
    select id
    from public.notifications
    where push_sent_at is null
      and created_at > now() - interval '24 hours'
      and (p_user is null or user_id = p_user)
    order by created_at
    limit greatest(1, least(p_limite, 500))
    for update skip locked
  )
  returning n.*;
$$;

revoke all on function public.reserver_notifications_a_pousser(integer, uuid) from public;
grant execute on function public.reserver_notifications_a_pousser(integer, uuid) to service_role;
