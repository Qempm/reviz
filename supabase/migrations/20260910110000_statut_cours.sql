-- Le statut d'un cours n'est pas au client d'en décider.
--
-- La politique « Je modifie mes cours » autorise l'UPDATE sur ses propres
-- lignes, colonnes comprises : un étudiant pouvait donc poser
-- `status = 'ready'` lui-même et faire croire à un cours traité, ou remettre
-- un cours abandonné en traitement à volonté.
--
-- Le dépôt a besoin d'une seule transition côté client : `uploaded` →
-- `processing`, quand le fichier est arrivé dans le bucket. Tout le reste —
-- `ready`, `failed` — appartient à la file de jobs, donc au rôle de service.

create or replace function public.protect_course_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Le rôle de service et les traitements en SECURITY DEFINER ne sont pas
  -- concernés : `auth.uid()` est nul hors d'une session authentifiée.
  if auth.uid() is null then
    return new;
  end if;

  if new.status is distinct from old.status
     and not (old.status = 'uploaded' and new.status = 'processing') then
    raise exception
      'Le statut d''un cours est posé par le traitement, pas par le client '
      '(tentative : % → %).', old.status, new.status
      using errcode = 'insufficient_privilege';
  end if;

  -- L'empreinte et le chemin de stockage identifient le fichier source :
  -- les changer après coup permettrait de faire passer un cours pour un
  -- autre et de contourner le cache de la règle métier 4.
  if new.file_hash is distinct from old.file_hash
     or new.storage_path is distinct from old.storage_path
     or new.owner_id is distinct from old.owner_id
     or new.is_demo is distinct from old.is_demo then
    raise exception
      'Empreinte, chemin, propriétaire et marque de démonstration d''un '
      'cours ne se modifient pas.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

comment on function public.protect_course_status() is
  'Verrouille les colonnes de courses qu''un client ne doit pas écrire. '
  'Même intention que protect_profile_columns() : une politique RLS accorde '
  'ou refuse une ligne entière, elle ne sait pas protéger une colonne.';

create trigger courses_protect_status
  before update on public.courses
  for each row
  execute function public.protect_course_status();

revoke all on function public.protect_course_status() from public;
revoke all on function public.protect_course_status() from anon;
