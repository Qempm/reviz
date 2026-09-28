-- Ne pas retraiter un document que quelqu'un a déjà fait traiter.
--
-- Règle métier 4 : « un document déjà traité par quelqu'un dans la même
-- faculté n'est jamais re-traité ». `courses.file_hash` et l'index
-- `courses_file_hash_ready_idx` étaient posés pour cela depuis le premier jour
-- et n'avaient jamais eu d'appelant, faute de traitement.
--
-- Ce que cela économise n'est pas théorique. Un polycopié de licence 1 circule
-- entre des centaines d'étudiants de la même faculté : le premier dépôt paie
-- une cinquantaine d'appels de modèle, les suivants n'en paient aucun. Sur un
-- budget de cinq dollars, c'est la différence entre dix cours et mille.
--
-- La copie est faite en SQL et non côté application, pour deux raisons : c'est
-- une seule transaction — un cours à moitié copié serait pire qu'un cours à
-- traiter —, et c'est quelques milliers de lignes qui n'ont aucune raison de
-- traverser une fonction serverless.

create or replace function public.copier_contenu_cours(
  p_source uuid,
  p_cible uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chapitres integer;
  v_questions integer;
  v_fiches integer;
begin
  -- Le cours cible doit être vierge : recopier par-dessus un contenu existant
  -- doublerait les questions, et le plafond de 200 par cours sauterait.
  if exists (select 1 from public.chapters where course_id = p_cible) then
    return jsonb_build_object('resultat', 'cible-non-vide');
  end if;

  if not exists (
    select 1 from public.courses
    where id = p_source and status = 'ready'
  ) then
    return jsonb_build_object('resultat', 'source-non-prete');
  end if;

  -- Les chapitres, en gardant la correspondance ancien → nouveau pour
  -- rattacher les questions et les fiches.
  with copies as (
    insert into public.chapters (course_id, index, title, text, token_count, embedding)
    select p_cible, c.index, c.title, c.text, c.token_count, c.embedding
    from public.chapters c
    where c.course_id = p_source
    order by c.index
    returning id, index
  )
  select count(*) into v_chapitres from copies;

  insert into public.questions
    (chapter_id, type, statement, options, answer, explanation, probability)
  select cible.id, q.type, q.statement, q.options, q.answer, q.explanation, q.probability
  from public.questions q
  join public.chapters source on source.id = q.chapter_id
  join public.chapters cible
    on cible.course_id = p_cible and cible.index = source.index
  where source.course_id = p_source;

  get diagnostics v_questions = row_count;

  insert into public.flashcards (chapter_id, front, back)
  select cible.id, f.front, f.back
  from public.flashcards f
  join public.chapters source on source.id = f.chapter_id
  join public.chapters cible
    on cible.course_id = p_cible and cible.index = source.index
  where source.course_id = p_source;

  get diagnostics v_fiches = row_count;

  -- La page compte aussi : elle vient du document, pas du traitement.
  update public.courses cible
  set page_count = source.page_count,
      status = 'ready'
  from public.courses source
  where cible.id = p_cible and source.id = p_source;

  return jsonb_build_object(
    'resultat', 'copie',
    'chapitres', v_chapitres,
    'questions', v_questions,
    'fiches', v_fiches
  );
end;
$$;

comment on function public.copier_contenu_cours(uuid, uuid) is
  'Recopie chapitres, questions et fiches d''un cours déjà traité vers un '
  'cours vierge de même empreinte, et le passe en ready. Une seule '
  'transaction (règle métier 4). Refuse une cible non vide : le plafond de '
  '200 questions par cours sauterait.';

-- Révoquer de PUBLIC **et** des rôles nommés avant d'accorder : les
-- privilèges par défaut de Supabase accordent EXECUTE nominativement à anon
-- comme à authenticated.
revoke all on function public.copier_contenu_cours(uuid, uuid) from public;
revoke all on function public.copier_contenu_cours(uuid, uuid) from anon;
revoke all on function public.copier_contenu_cours(uuid, uuid) from authenticated;
grant execute on function public.copier_contenu_cours(uuid, uuid) to service_role;

-- Trouver un cours déjà traité pour une empreinte, dans la même faculté.
--
-- « Dans la même faculté » est la limite que pose la règle : un cours n'est
-- réutilisable que s'il a été partagé (`shared_with_faculty`) et que son
-- propriétaire appartient à la faculté du demandeur. Sans cela, l'empreinte
-- deviendrait un canal de lecture entre facultés.
create or replace function public.cours_deja_traite(p_cours uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with demandeur as (
    select c.file_hash, p.faculty_id
    from public.courses c
    join public.profiles p on p.id = c.owner_id
    where c.id = p_cours
  )
  select source.id
  from public.courses source
  join public.profiles proprietaire on proprietaire.id = source.owner_id
  join demandeur d
    on d.file_hash = source.file_hash
   and d.faculty_id is not null
   and proprietaire.faculty_id = d.faculty_id
  where source.id <> p_cours
    and source.status = 'ready'
    and source.shared_with_faculty
    and exists (select 1 from public.chapters where course_id = source.id)
  order by source.created_at asc
  limit 1;
$$;

comment on function public.cours_deja_traite(uuid) is
  'Identifiant d''un cours déjà traité portant la même empreinte, partagé à '
  'la faculté, et appartenant à un membre de la même faculté que le '
  'demandeur. NULL sinon. Réservée au rôle de service : elle traverse les '
  'lignes d''autres étudiants.';

revoke all on function public.cours_deja_traite(uuid) from public;
revoke all on function public.cours_deja_traite(uuid) from anon;
revoke all on function public.cours_deja_traite(uuid) from authenticated;
grant execute on function public.cours_deja_traite(uuid) to service_role;
