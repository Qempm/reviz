-- Politiques de sécurité au niveau ligne.
--
-- Principe (CLAUDE.md) : un utilisateur ne lit et n'écrit que ses propres
-- lignes ; les cours partagés à la faculté sont lisibles par cette faculté ;
-- les tables financières ne sont écrites que par le rôle de service.
--
-- Le rôle `service_role` contourne la RLS : il n'a donc aucune politique ici.
-- Une table dont la RLS est activée sans aucune politique est fermée à tous
-- les autres rôles, ce qui est le comportement voulu pour jobs et ai_usage.

-- Fonctions d'aide ----------------------------------------------------------

-- Lire profiles depuis une politique de profiles provoquerait une récursion
-- infinie : ces fonctions sont SECURITY DEFINER pour y échapper.

create or replace function public.current_faculty_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select faculty_id from public.profiles where id = auth.uid();
$$;

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
        c.owner_id = auth.uid()
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

-- Données de référence : lecture ouverte ------------------------------------

alter table public.universities enable row level security;
alter table public.faculties enable row level security;
alter table public.subjects enable row level security;
alter table public.packs enable row level security;

create policy "Universités lisibles par tous"
  on public.universities for select
  to anon, authenticated
  using (true);

create policy "Facultés lisibles par tous"
  on public.faculties for select
  to anon, authenticated
  using (true);

create policy "Matières lisibles par tous"
  on public.subjects for select
  to anon, authenticated
  using (true);

-- La boutique doit être consultable avant même de créer un compte.
create policy "Packs en vente lisibles par tous"
  on public.packs for select
  to anon, authenticated
  using (
    active_from <= now() and (active_to is null or active_to > now())
  );

-- Profils -------------------------------------------------------------------

alter table public.profiles enable row level security;

create policy "Je lis mon profil"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy "Je crée mon profil"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "Je modifie mon profil"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Le gel des colonnes sensibles passe par un trigger et non par le WITH CHECK
-- de la politique : une sous-requête sur profiles depuis une politique de
-- profiles serait elle-même soumise à la RLS, donc récursive.
--
-- Le statut de vérification, sa date de fin, le rang d'ambassadeur et le code
-- de parrainage sont posés par le job verify_card et par l'administration,
-- via le rôle de service.
create or replace function public.protect_profile_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le rôle de service et les traitements internes gardent la main.
  if auth.uid() is null or auth.uid() <> old.id then
    return new;
  end if;

  new.verification_status := old.verification_status;
  new.verified_until      := old.verified_until;
  new.is_ambassador       := old.is_ambassador;
  new.referral_code       := old.referral_code;
  new.student_card_hash   := old.student_card_hash;
  new.referred_by         := old.referred_by;

  return new;
end;
$$;

create trigger profiles_protect_columns
  before update on public.profiles
  for each row
  execute function public.protect_profile_columns();

-- Cours et contenu généré ---------------------------------------------------

alter table public.courses enable row level security;
alter table public.chapters enable row level security;
alter table public.questions enable row level security;
alter table public.flashcards enable row level security;

create policy "Je lis mes cours et ceux partagés dans ma faculté"
  on public.courses for select
  to authenticated
  using (public.can_read_course(id));

create policy "J'ajoute un cours"
  on public.courses for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "Je modifie mes cours"
  on public.courses for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "Je supprime mes cours"
  on public.courses for delete
  to authenticated
  using (owner_id = auth.uid());

-- Le contenu généré suit la visibilité de son cours. Il est produit par les
-- jobs, donc en lecture seule côté client.

create policy "Je lis les chapitres des cours visibles"
  on public.chapters for select
  to authenticated
  using (public.can_read_course(course_id));

create policy "Je lis les questions des cours visibles"
  on public.questions for select
  to authenticated
  using (
    exists (
      select 1 from public.chapters c
      where c.id = questions.chapter_id
        and public.can_read_course(c.course_id)
    )
  );

create policy "Je lis les fiches des cours visibles"
  on public.flashcards for select
  to authenticated
  using (
    exists (
      select 1 from public.chapters c
      where c.id = flashcards.chapter_id
        and public.can_read_course(c.course_id)
    )
  );

-- Réponses et corrections ---------------------------------------------------

alter table public.attempts enable row level security;
alter table public.corrections enable row level security;

create policy "Je lis mes réponses"
  on public.attempts for select
  to authenticated
  using (user_id = auth.uid());

create policy "J'enregistre mes réponses"
  on public.attempts for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Je lis mes corrections"
  on public.corrections for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je demande une correction"
  on public.corrections for insert
  to authenticated
  with check (
    user_id = auth.uid()
    -- La note et le barème sont posés par le job correct_copy.
    and status = 'pending'
    and grade is null
    and max_grade is null
  );

-- Tables financières : lecture seule ---------------------------------------
--
-- Aucune politique d'écriture, volontairement. Les paiements, activations de
-- pack, commissions et retraits passent tous par le rôle de service
-- (webhook FedaPay, Server Actions), qui contourne la RLS.

alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.withdrawals enable row level security;
alter table public.referrals enable row level security;

create policy "Je lis mes paiements"
  on public.payments for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je lis mes accès"
  on public.subscriptions for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je lis mon grand livre"
  on public.wallet_ledger for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je lis mes retraits"
  on public.withdrawals for select
  to authenticated
  using (user_id = auth.uid());

create policy "Je lis mes parrainages"
  on public.referrals for select
  to authenticated
  using (referrer_id = auth.uid() or referred_id = auth.uid());

-- File de traitement : fermée au client ------------------------------------

alter table public.jobs enable row level security;
alter table public.ai_usage enable row level security;
