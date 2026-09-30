-- La maîtrise d'un chapitre, corrigée.
--
-- Trois défauts vérifiés le 30 septembre 2026 dans la vue d'origine :
--  - `is_weak` exigeait cinq questions tentées, or un chapitre en portait
--    quatre : jamais vrai ;
--  - `taux` divisait les justes par les questions **tentées** : une seule
--    bonne réponse sur quatre questions affichait 100 % ;
--  - les questions de secours (`open`), sans réponse possible, comptaient.
--
-- Même règle que `lib/metier/maitrise.ts` et `apps/mobile/lib/metier/
-- maitrise.dart` (les couronnes sont calculées là, avec les jours) : QCM
-- seulement, dernière réponse à chacun, taux sur l'ensemble du chapitre.
-- Mêmes colonnes, dans le même ordre : `create or replace` ne peut rien
-- renommer, et l'application lit ces noms-là.

create or replace view public.chapter_stats
with (security_invoker = on)
as
with derniere as (
  select distinct on (a.user_id, a.question_id)
    a.user_id,
    a.question_id,
    a.is_correct
  from public.attempts a
  order by a.user_id, a.question_id, a.answered_at desc, a.id desc
),
par_chapitre as (
  select
    ch.id,
    ch.course_id,
    ch.index,
    ch.title,
    count(distinct q.id)::integer as nb_questions,
    count(distinct fl.id)::integer as nb_fiches,
    count(distinct d.question_id)::integer as nb_tentees,
    count(distinct d.question_id) filter (where d.is_correct)::integer as nb_justes
  from public.chapters ch
  left join public.questions q on q.chapter_id = ch.id and q.type = 'mcq'
  left join public.flashcards fl on fl.chapter_id = ch.id
  left join derniere d on d.question_id = q.id and d.user_id = auth.uid()
  group by ch.id, ch.course_id, ch.index, ch.title
)
select
  id as chapter_id,
  course_id,
  index,
  title,
  nb_questions,
  nb_fiches,
  nb_tentees,
  nb_justes,
  -- `null` tant que rien n'a été tenté ; sinon rapporté à **tout** le
  -- chapitre, et non aux seules questions tentées.
  case
    when nb_tentees = 0 or nb_questions = 0 then null
    else round(nb_justes::numeric / nb_questions, 3)
  end as taux,
  -- À revoir : au moins la moitié tentée, et moins de la moitié juste.
  (
    nb_questions > 0
    and nb_tentees * 2 >= nb_questions
    and nb_justes * 2 < nb_tentees
  ) as is_weak
from par_chapitre;

comment on view public.chapter_stats is
  'Un chapitre, ses QCM et la maîtrise de l''appelant sur la dernière '
  'réponse à chacun. `taux` : justes sur tous les QCM du chapitre, null '
  'quand rien n''a été tenté. Couronnes : lib/metier/maitrise.ts.';
