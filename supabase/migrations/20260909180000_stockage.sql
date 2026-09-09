-- Espaces de stockage : cours, copies, cartes étudiantes, avatars.
--
-- Convention de chemin, imposée par les politiques ci-dessous :
--
--   <bucket>/<id de l'étudiant>/<reste>
--
-- Le premier segment sert de clé de propriété. `storage.foldername(name)`
-- le renvoie, ce qui permet d'écrire des politiques sans table de jointure.
-- Toute écriture hors de son propre dossier est refusée.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Cours : PDF, Word, images. 25 Mo couvre un polycopié scanné.
  (
    'cours', 'cours', false, 26214400,
    array[
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/msword',
      'image/jpeg', 'image/png', 'image/webp'
    ]
  ),
  -- Copies photographiées : images uniquement, plusieurs par correction.
  (
    'copies', 'copies', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  -- Cartes étudiantes : une photo, lue par le job verify_card.
  (
    'cartes', 'cartes', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  -- Avatars : publics, ce sont les 24 illustrations livrées avec l'app.
  (
    'avatars', 'avatars', true, 2097152,
    array['image/png', 'image/webp', 'image/jpeg']
  )
on conflict (id) do nothing;

-- Cours ---------------------------------------------------------------------

create policy "Je dépose mes cours"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'cours'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Je lis mes cours"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'cours'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Je supprime mes cours"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'cours'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Le partage à la faculté ne passe pas par une politique de stockage : le
-- fichier source reste privé à son propriétaire. Ce qui est partagé, ce sont
-- les chapitres et les questions déjà extraits, dans la base — c'est le sens
-- du cache par file_hash (règle métier 4). Personne ne télécharge le PDF
-- d'un autre.

-- Copies --------------------------------------------------------------------

create policy "Je dépose mes copies"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'copies'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Je lis mes copies"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'copies'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Je supprime mes copies"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'copies'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Cartes étudiantes ---------------------------------------------------------
--
-- Dépôt et suppression seulement. Pas de lecture par le client : une carte
-- d'identité étudiante n'a pas à être re-téléchargeable depuis le navigateur,
-- même par son propriétaire. Le job verify_card la lit avec le rôle de
-- service, qui contourne ces politiques.

create policy "Je dépose ma carte"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'cartes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Je supprime ma carte"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'cartes'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Avatars -------------------------------------------------------------------
--
-- Bucket public : la lecture ne passe pas par une politique. Les fichiers
-- sont livrés avec l'application, aucune écriture depuis le client.
