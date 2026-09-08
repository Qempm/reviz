-- Extensions et types énumérés partagés.
--
-- Les valeurs des énumérations sont celles de CLAUDE.md, section
-- « Modèle de données ». Toute valeur ajoutée ici doit l'être aussi là-bas.

create extension if not exists "pgcrypto" with schema extensions;
create extension if not exists "vector" with schema extensions;

-- Profils -------------------------------------------------------------------

create type public.verification_status as enum (
  'none',
  'pending',
  'verified',
  'rejected'
);

-- Cours et révision ---------------------------------------------------------

create type public.course_status as enum (
  'uploaded',
  'processing',
  'ready',
  'failed'
);

create type public.question_type as enum ('mcq', 'open');

create type public.question_probability as enum ('high', 'medium', 'low');

-- Correction de copies ------------------------------------------------------

create type public.correction_status as enum (
  'pending',
  'processing',
  'ready',
  'failed'
);

-- Packs et paiement ---------------------------------------------------------

create type public.pack_code as enum (
  'decouverte',
  'controle',
  'partiel',
  'semestre',
  'rattrapage'
);

create type public.payment_status as enum ('pending', 'success', 'failed');

create type public.subscription_source as enum (
  'payment',
  'class_purchase',
  'bonus'
);

-- Portefeuille --------------------------------------------------------------

create type public.ledger_entry_type as enum (
  'referral_commission',
  'sale',
  'withdrawal',
  'adjustment'
);

create type public.withdrawal_status as enum (
  'requested',
  'processing',
  'paid',
  'rejected'
);

-- File de traitement --------------------------------------------------------

create type public.job_type as enum (
  'ingest_course',
  'generate_questions',
  'correct_copy',
  'verify_card',
  'notify'
);

create type public.job_status as enum (
  'queued',
  'running',
  'done',
  'failed'
);
