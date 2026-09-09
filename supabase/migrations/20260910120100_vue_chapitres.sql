-- Maîtrise par chapitre, pour les onglets « Chapitres » et « À revoir ».
--
-- Écrite en SQL et non en JavaScript : l'alternative était de rapatrier
-- toutes les réponses du cours dans la page pour les regrouper côté client.
-- Sur un cours de 200 questions révisé plusieurs fois, cela fait quelques
-- centaines de lignes transférées à chaque affichage, pour en tirer quatre
-- chiffres. La cible a un forfait limité.
--
-- Même règle que `subject_stats` depuis 20260910120000 : le taux se calcule
-- sur la **dernière** tentative de chaque question, pas sur toutes.

create view public.chapter_stats
with (security_invoker = on)
as
with derniere as (
  select distinct on (a.user_id, a.question_id)
    a.user_id,
    a.question_id,
    a.is_correct
  from public.attempts a
  order by a.user_id, a.question_id, a.answered_at desc, a.id desc
)
select
  ch.id as chapter_id,
  ch.course_id,
  ch.index,
  ch.title,
  count(distinct q.id)::integer as nb_questions,
  count(distinct fl.id)::integer as nb_fiches,
  count(distinct d.question_id)::integer as nb_tentees,
  count(distinct q.id) filter (where d.is_correct)::integer as nb_justes,
  -- `null` tant que rien n'a été tenté : un chapitre jamais ouvert n'a pas
  -- un taux de 0 %, il n'a pas de taux. La nuance change l'affichage.
  case
    when count(distinct d.question_id) = 0 then null
    else round(
      count(distinct q.id) filter (where d.is_correct)::numeric
        / count(distinct d.question_id),
      3
    )
  end as taux,
  -- Point faible : au moins cinq questions tentées et moins de la moitié de
  -- justes. Le seuil est plus bas que celui de `subject_stats` (dix), un
  -- chapitre portant naturellement moins de questions qu'une matière.
  (
    count(distinct d.question_id) >= 5
    and count(distinct q.id) filter (where d.is_correct)
        < count(distinct d.question_id)::numeric / 2
  ) as is_weak
from public.chapters ch
left join public.questions q on q.chapter_id = ch.id
left join public.flashcards fl on fl.chapter_id = ch.id
left join derniere d on d.question_id = q.id and d.user_id = auth.uid()
group by ch.id, ch.course_id, ch.index, ch.title;

comment on view public.chapter_stats is
  'Un chapitre avec ses décomptes et la maîtrise de l''appelant, calculée '
  'sur la dernière tentative de chaque question. `taux` vaut null quand '
  'rien n''a été tenté : un chapitre jamais ouvert n''a pas un taux de 0 %, '
  'il n''a pas de taux.';

-- La lecture est cloisonnée par la politique de `chapters`, qui délègue à
-- `can_read_course()` : la vue en security_invoker n'ouvre rien de plus.
revoke all on public.chapter_stats from public;
revoke all on public.chapter_stats from anon;
grant select on public.chapter_stats to authenticated;
