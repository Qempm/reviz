-- Le taux de maîtrise doit refléter ce que l'étudiant sait, pas ce qu'il a su.
--
-- `subject_stats` moyennait **toutes** les tentatives. Trois conséquences,
-- toutes visibles à l'écran :
--
--   1. Refaire une session compte les mêmes questions une seconde fois.
--      `attempts` n'a aucune contrainte d'unicité — c'est voulu, le journal
--      des réponses est un historique — mais la moyenne, elle, devient un
--      décompte de sessions.
--   2. Une matière ratée puis reprise reste faible longtemps : les échecs
--      d'hier pèsent autant que les réussites d'aujourd'hui.
--   3. `questions_answered` disait « 40 questions répondues » pour 10
--      questions faites quatre fois.
--
-- La vue ne garde donc que la **dernière** tentative par question, tout en
-- exposant le total historique à part : rien n'est perdu, et le chiffre
-- affiché redevient un taux de maîtrise.

drop view if exists public.subject_stats;

create view public.subject_stats
with (security_invoker = on)
as
with derniere as (
  -- `distinct on` garde la première ligne de chaque groupe : l'ordre par
  -- date décroissante en fait la plus récente. Un `answered_at` à égalité
  -- se tranche par l'identifiant, pour que le résultat soit déterministe.
  select distinct on (a.user_id, a.question_id)
    a.user_id,
    a.question_id,
    a.is_correct,
    a.answered_at
  from public.attempts a
  order by a.user_id, a.question_id, a.answered_at desc, a.id desc
),
totaux as (
  select user_id, question_id, count(*)::integer as nb
  from public.attempts
  group by user_id, question_id
)
select
  d.user_id,
  s.id as subject_id,
  s.name as subject_name,
  s.faculty_id,
  -- Questions distinctes, et non tentatives : c'est le sens du mot.
  count(*)::integer as questions_answered,
  count(*) filter (where d.is_correct)::integer as correct_count,
  -- Total historique, conservé pour l'assiduité : « tu as répondu 120 fois »
  -- reste une information, elle n'a simplement rien à faire dans un taux.
  coalesce(sum(t.nb), 0)::integer as attempts_total,
  round(avg(case when d.is_correct then 1 else 0 end)::numeric, 3) as average_score,
  -- Point faible : moins de la moitié de bonnes réponses sur un échantillon
  -- assez large pour être significatif.
  (
    count(*) >= 10
    and avg(case when d.is_correct then 1 else 0 end) < 0.5
  ) as is_weak,
  max(d.answered_at) as last_answered_at
from derniere d
join totaux t on t.user_id = d.user_id and t.question_id = d.question_id
join public.questions q on q.id = d.question_id
join public.chapters ch on ch.id = q.chapter_id
join public.courses c on c.id = ch.course_id
join public.subjects s on s.id = c.subject_id
group by d.user_id, s.id, s.name, s.faculty_id;

comment on view public.subject_stats is
  'Taux de maîtrise par matière pour l''étudiant connecté, calculé sur la '
  'dernière tentative de chaque question — refaire une session corrige le '
  'score au lieu de le diluer. `attempts_total` garde le compte historique. '
  'Ne couvre que les cours rattachés à une matière : un cours sans '
  'subject_id n''y apparaît pas.';

-- security_invoker : la vue s'exécute avec les droits de l'appelant, donc la
-- politique « Je lis mes réponses » (`user_id = auth.uid()`) suffit à
-- cloisonner. Les droits sont remis à zéro par le `drop`, il faut les
-- reposer — voir 20260909150000_revoque_anon.sql.
revoke all on public.subject_stats from public;
revoke all on public.subject_stats from anon;
grant select on public.subject_stats to authenticated;
