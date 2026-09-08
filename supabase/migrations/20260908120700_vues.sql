-- Vues de restitution.

-- Statistiques par matière : score moyen, questions faites, points faibles
-- (CLAUDE.md, section « Modèle de données », table attempts).
--
-- security_invoker = on : la vue s'exécute avec les droits de l'appelant, donc
-- la RLS de attempts s'applique et chacun ne voit que ses propres chiffres.
create view public.subject_stats
with (security_invoker = on)
as
select
  a.user_id,
  s.id as subject_id,
  s.name as subject_name,
  s.faculty_id,
  count(*)::integer as questions_answered,
  count(*) filter (where a.is_correct)::integer as correct_count,
  round(
    avg(case when a.is_correct then 1 else 0 end)::numeric,
    3
  ) as average_score,
  -- Point faible : moins de la moitié de bonnes réponses sur un échantillon
  -- suffisant pour être significatif.
  (
    count(*) >= 10
    and avg(case when a.is_correct then 1 else 0 end) < 0.5
  ) as is_weak,
  max(a.answered_at) as last_answered_at
from public.attempts a
join public.questions q on q.id = a.question_id
join public.chapters ch on ch.id = q.chapter_id
join public.courses c on c.id = ch.course_id
join public.subjects s on s.id = c.subject_id
group by a.user_id, s.id, s.name, s.faculty_id;

comment on view public.subject_stats is
  'Score par matière pour l''étudiant connecté. Ne compte que les cours '
  'rattachés à une matière : un cours sans subject_id n''y apparaît pas.';

-- Accès en cours ------------------------------------------------------------

-- Raccourci pour l'écran « pack expiré » et les gardes d'accès.
create view public.active_subscriptions
with (security_invoker = on)
as
select
  s.*,
  p.label as pack_label,
  p.subjects_limit,
  greatest(0, extract(day from s.ends_at - now())::integer) as days_left
from public.subscriptions s
join public.packs p on p.code = s.pack_code
where s.starts_at <= now()
  and s.ends_at > now();

comment on view public.active_subscriptions is
  'Accès valides à l''instant présent. À ends_at la ligne disparaît d''elle-même : '
  'aucun renouvellement automatique (CLAUDE.md, règle métier 1).';
