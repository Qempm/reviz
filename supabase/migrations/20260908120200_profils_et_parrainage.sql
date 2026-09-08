-- Profils étudiants et liens de parrainage.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text not null unique,
  first_name text,
  university_id uuid references public.universities (id) on delete set null,
  faculty_id uuid references public.faculties (id) on delete set null,
  study_year smallint check (study_year between 1 and 7),
  avatar_key text,
  verification_status public.verification_status not null default 'none',
  verified_until timestamptz,
  student_card_hash text,
  referral_code text not null unique,
  referred_by uuid references public.profiles (id) on delete set null,
  is_ambassador boolean not null default false,
  created_at timestamptz not null default now(),

  -- Anti-fraude : on ne peut pas être son propre parrain (règle métier 3).
  constraint profiles_pas_son_propre_parrain check (referred_by is distinct from id)
);

comment on column public.profiles.phone is
  'Un numéro ne peut ouvrir qu''un seul compte (règle métier 3).';

comment on column public.profiles.student_card_hash is
  'Empreinte de la carte étudiante, pour empêcher qu''une même carte serve '
  'à plusieurs comptes (règle métier 3). Renseignée par le job verify_card.';

comment on column public.profiles.is_ambassador is
  'Ambassadeur : commission de parrainage à 35 %% au lieu de 25 %%.';

-- Une même carte étudiante ne peut servir qu'une fois (règle métier 3).
create unique index profiles_student_card_hash_idx
  on public.profiles (student_card_hash)
  where student_card_hash is not null;

create index profiles_referred_by_idx on public.profiles (referred_by);
create index profiles_faculty_id_idx on public.profiles (faculty_id);

-- Génération du code de parrainage -----------------------------------------

-- Alphabet sans les caractères ambigus (0/O, 1/I/L) : le code est dicté à
-- l'oral et recopié à la main.
create or replace function public.generate_referral_code()
returns text
language plpgsql
volatile
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  candidate text;
  i integer;
begin
  loop
    candidate := '';
    for i in 1..6 loop
      candidate := candidate
        || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;

    exit when not exists (
      select 1 from public.profiles where referral_code = candidate
    );
  end loop;

  return candidate;
end;
$$;

alter table public.profiles
  alter column referral_code set default public.generate_referral_code();

-- Parrainages ---------------------------------------------------------------

create table public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.profiles (id) on delete cascade,
  referred_id uuid not null references public.profiles (id) on delete cascade,
  first_payment_at timestamptz,
  commission_rate numeric(4, 3) not null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),

  unique (referred_id),
  constraint referrals_pas_soi_meme check (referrer_id <> referred_id),
  -- 25 % en temps normal, 35 % pour un ambassadeur (règle métier 2).
  constraint referrals_taux_connu check (commission_rate in (0.250, 0.350)),
  -- La fenêtre de commission court 12 mois à partir du premier paiement.
  constraint referrals_expiration_coherente check (
    (first_payment_at is null and expires_at is null)
    or (first_payment_at is not null and expires_at = first_payment_at + interval '12 months')
  )
);

comment on table public.referrals is
  'Un filleul ne compte que s''il est vérifié et a payé au moins une fois : '
  'first_payment_at reste NULL tant que ce n''est pas le cas '
  '(CLAUDE.md, règle métier 2).';

create index referrals_referrer_id_idx on public.referrals (referrer_id);

-- Renseigne expires_at à 12 mois dès que le premier paiement est constaté.
create or replace function public.set_referral_expiry()
returns trigger
language plpgsql
as $$
begin
  if new.first_payment_at is not null then
    new.expires_at := new.first_payment_at + interval '12 months';
  else
    new.expires_at := null;
  end if;

  return new;
end;
$$;

create trigger referrals_expiry
  before insert or update of first_payment_at on public.referrals
  for each row
  execute function public.set_referral_expiry();
