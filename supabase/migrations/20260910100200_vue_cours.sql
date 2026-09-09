-- Vue de synthèse d'un cours : chapitres, questions, fiches, progression.
--
-- Sans elle, chaque écran refarait les mêmes agrégats à la main, et la liste
-- des cours aurait exigé un aller-retour par cours — inacceptable sur une
-- connexion instable.
--
-- security_invoker = on : la vue s'exécute avec les droits de l'appelant, donc
-- la politique de `courses` (propriétaire, faculté, ou démonstration)
-- s'applique telle quelle. Aucune fuite possible par la vue.

create view public.course_overview
with (security_invoker = on)
as
select
  c.id,
  c.owner_id,
  c.subject_id,
  c.title,
  c.status,
  c.is_demo,
  c.shared_with_faculty,
  c.exam_date,
  c.page_count,
  c.created_at,
  s.name as subject_name,
  s.faculty_id,
  coalesce(ch.nb_chapitres, 0)::integer as nb_chapitres,
  coalesce(ch.nb_questions, 0)::integer as nb_questions,
  coalesce(ch.nb_fiches, 0)::integer as nb_fiches,
  -- Nombre de questions déjà tentées par l'appelant, pour la progression.
  coalesce(mes.nb_tentees, 0)::integer as nb_tentees
from public.courses c
left join public.subjects s on s.id = c.subject_id
left join (
  select
    ch.course_id,
    count(distinct ch.id) as nb_chapitres,
    count(distinct q.id) as nb_questions,
    count(distinct fl.id) as nb_fiches
  from public.chapters ch
  left join public.questions q on q.chapter_id = ch.id
  left join public.flashcards fl on fl.chapter_id = ch.id
  group by ch.course_id
) ch on ch.course_id = c.id
left join (
  select ch.course_id, count(distinct a.question_id) as nb_tentees
  from public.attempts a
  join public.questions q on q.id = a.question_id
  join public.chapters ch on ch.id = q.chapter_id
  where a.user_id = auth.uid()
  group by ch.course_id
) mes on mes.course_id = c.id;

comment on view public.course_overview is
  'Un cours avec ses décomptes et la progression de l''appelant. '
  'nb_tentees compte les questions distinctes déjà tentées, pas les '
  'tentatives : refaire une session ne fait pas dépasser 100 %.';
