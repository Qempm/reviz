-- Le téléphone n'est plus une identité, seulement une donnée de profil.
--
-- Décision du 9 septembre 2026 : la connexion se fait par Google ou par
-- email, l'OTP téléphone est abandonné comme moyen d'authentification. Le
-- numéro devient facultatif.
--
-- Conséquence sur la règle métier 3 : l'unicité du numéro ne peut plus servir
-- de barrière anti-fraude, puisqu'un compte peut exister sans numéro. C'est
-- désormais l'empreinte de la carte étudiante qui porte seule cette fonction
-- — voir l'index unique sur student_card_hash, inchangé.
--
-- La contrainte UNIQUE est conservée : Postgres autorise plusieurs NULL dans
-- un index unique, donc « un compte par numéro » reste vrai pour tous ceux
-- qui en renseignent un.

alter table public.profiles
  alter column phone drop not null;

comment on column public.profiles.phone is
  'Facultatif depuis le passage à Google/email. Reste unique quand il est '
  'renseigné. Sert aux notifications WhatsApp : un étudiant sans numéro n''en '
  'reçoit aucune. N''est pas vérifié — ne pas s''en servir comme preuve '
  'd''identité.';

comment on column public.profiles.student_card_hash is
  'Empreinte de la carte étudiante. Depuis que le téléphone est facultatif, '
  'c''est la seule barrière anti-fraude « un compte par personne » '
  '(CLAUDE.md, règle métier 3).';
