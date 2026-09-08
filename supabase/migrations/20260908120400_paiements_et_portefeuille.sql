-- Paiements Mobile Money, accès achetés et portefeuille de parrainage.
--
-- Toutes les tables de ce fichier sont écrites exclusivement par le rôle de
-- service : webhook de paiement, traitement des retraits, ajustements manuels.
-- Le client ne peut que lire ses propres lignes.

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  provider text not null,
  provider_ref text,
  amount_fcfa integer not null check (amount_fcfa > 0),
  operator text,
  phone text,
  status public.payment_status not null default 'pending',
  pack_code public.pack_code not null references public.packs (code),
  raw jsonb,
  created_at timestamptz not null default now(),

  -- Garde-fou d'idempotence du webhook : une référence fournisseur ne peut
  -- être traitée qu'une fois.
  unique (provider, provider_ref)
);

comment on column public.payments.provider is
  'Implémentation de lib/payments/provider.ts ayant traité l''opération '
  '(fedapay, moneroo, kkiapay…).';

create index payments_user_id_created_at_idx
  on public.payments (user_id, created_at desc);

-- Accès achetés -------------------------------------------------------------

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  pack_code public.pack_code not null references public.packs (code),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  corrections_left smallint not null default 0 check (corrections_left >= 0),
  source public.subscription_source not null,
  payment_id uuid references public.payments (id) on delete set null,
  created_at timestamptz not null default now(),

  constraint subscriptions_periode_coherente check (ends_at > starts_at)
);

comment on table public.subscriptions is
  'Accès à durée limitée, sans renouvellement automatique. À ends_at l''accès '
  's''arrête : lecture seule des cours et de l''historique '
  '(CLAUDE.md, règle métier 1). Aucune colonne de reconduction, volontairement.';

create index subscriptions_user_id_ends_at_idx
  on public.subscriptions (user_id, ends_at desc);

-- Un abonnement en cours pour un utilisateur donné.
create index subscriptions_actives_idx
  on public.subscriptions (user_id, starts_at, ends_at);

-- Portefeuille --------------------------------------------------------------

create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  type public.ledger_entry_type not null,
  -- Positif pour un gain, négatif pour un retrait ou un ajustement débiteur.
  amount_fcfa integer not null check (amount_fcfa <> 0),
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

comment on table public.wallet_ledger is
  'Grand livre immuable : uniquement des INSERT. Le solde est la somme des '
  'lignes, jamais une colonne (CLAUDE.md, règle métier 2). Une erreur se '
  'corrige par une écriture de type adjustment, pas par une modification.';

create index wallet_ledger_user_id_created_at_idx
  on public.wallet_ledger (user_id, created_at desc);

create index wallet_ledger_reference_id_idx
  on public.wallet_ledger (reference_id)
  where reference_id is not null;

-- Interdit toute modification ou suppression, y compris au rôle de service.
create or replace function public.wallet_ledger_is_immutable()
returns trigger
language plpgsql
as $$
begin
  raise exception
    'wallet_ledger est un grand livre immuable : seuls les INSERT sont '
    'autorisés. Pour corriger une écriture, ajouter une ligne de type '
    'adjustment.'
    using errcode = 'restrict_violation';
end;
$$;

create trigger wallet_ledger_no_update
  before update on public.wallet_ledger
  for each row
  execute function public.wallet_ledger_is_immutable();

create trigger wallet_ledger_no_delete
  before delete on public.wallet_ledger
  for each row
  execute function public.wallet_ledger_is_immutable();

-- Solde d'un étudiant : somme du grand livre.
create or replace function public.wallet_balance(target uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(amount_fcfa), 0)::integer
  from public.wallet_ledger
  where user_id = target;
$$;

-- Retraits ------------------------------------------------------------------

create table public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  -- Seuil de retrait à 3 000 F (CLAUDE.md, règle métier 2).
  amount_fcfa integer not null check (amount_fcfa >= 3000),
  operator text not null,
  phone text not null,
  status public.withdrawal_status not null default 'requested',
  requested_at timestamptz not null default now(),
  paid_at timestamptz,
  failure_reason text,

  constraint withdrawals_paiement_coherent check (
    (status = 'paid' and paid_at is not null)
    or (status <> 'paid' and paid_at is null)
  )
);

create index withdrawals_user_id_requested_at_idx
  on public.withdrawals (user_id, requested_at desc);
