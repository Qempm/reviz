-- Le push sur iPhone sans compte Apple (arbitrage du 5 octobre 2026).
--
-- Sur iPhone, Reviz est l'app web installée depuis Safari. Depuis iOS 16.4,
-- une app web installée reçoit des notifications par le Web Push standard
-- (clés VAPID, sans Firebase ni compte Apple) : un « abonnement » tient lieu
-- de jeton. Il porte une adresse d'envoi (la clé de la ligne, comme le jeton
-- FCM) et deux clés de chiffrement, gardées dans `abonnement`.

alter table public.appareils
  drop constraint appareils_plateforme_check;

alter table public.appareils
  add constraint appareils_plateforme_check
  check (plateforme in ('android', 'ios', 'web'));

alter table public.appareils
  add column abonnement jsonb;

-- Un abonnement web sans ses clés ne peut rien recevoir : il est refusé.
-- `coalesce` : sans lui, un abonnement NULL rend la condition NULL, et une
-- contrainte NULL laisse passer (l'essai annulé l'a montré).
alter table public.appareils
  add constraint appareils_abonnement_web
  check (
    plateforme <> 'web'
    or coalesce(abonnement ? 'p256dh' and abonnement ? 'auth', false)
  );

comment on column public.appareils.abonnement is
  'Web Push seulement : les clés p256dh et auth de l''abonnement du '
  'navigateur. Le jeton (token) est alors l''adresse d''envoi (endpoint).';
