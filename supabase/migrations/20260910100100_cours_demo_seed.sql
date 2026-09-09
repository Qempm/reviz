-- Cours de démonstration : Droit constitutionnel (UAC / FADESP).
--
-- Contenu rédigé à la main, sur le droit constitutionnel béninois. Il sert
-- d'étalon : quand l'IA produira des QCM, c'est à ce niveau de précision
-- qu'on les comparera.
--
-- Idempotent : identifiants fixes et `on conflict do nothing`. Retirable d'une
-- commande — `delete from public.courses where is_demo` emporte chapitres,
-- questions et fiches par cascade.

-- Cours ---------------------------------------------------------------------

insert into public.courses
  (id, owner_id, subject_id, title, file_hash, storage_path, page_count,
   status, shared_with_faculty, is_demo)
select
  '0d000000-0000-4000-8000-000000000001',
  null,
  s.id,
  'Droit constitutionnel — introduction',
  'demo:droit-constitutionnel:v1',
  'demo/droit-constitutionnel.pdf',
  42,
  'ready',
  false,
  true
from public.subjects s
join public.faculties f on f.id = s.faculty_id
join public.universities u on u.id = f.university_id
where u.code = 'UAC' and f.code = 'FADESP' and s.name = 'Droit constitutionnel'
on conflict (id) do nothing;

-- Chapitres -----------------------------------------------------------------

insert into public.chapters (id, course_id, index, title, text, token_count) values
(
  '0d000000-0000-4000-8000-000000000101',
  '0d000000-0000-4000-8000-000000000001',
  1,
  'La Constitution du 11 décembre 1990',
  E'La Constitution béninoise en vigueur a été adoptée par référendum le 2 décembre 1990 et promulguée le 11 décembre 1990. Elle clôt la période du Renouveau démocratique ouverte par la Conférence des Forces Vives de la Nation, réunie à Cotonou du 19 au 28 février 1990.\n\nCette conférence marque une rupture : elle met fin au régime du Parti de la Révolution Populaire du Bénin et installe une transition dirigée par un Premier ministre. Le texte qui en résulte organise un régime présidentiel, avec une séparation nette des pouvoirs et un contrôle de constitutionnalité confié à une juridiction spécialisée.\n\nLa Constitution a été révisée en 2019. Cette révision a notamment touché le régime électoral et la composition de certaines institutions, sans remettre en cause l''architecture d''ensemble héritée de 1990.',
  340
),
(
  '0d000000-0000-4000-8000-000000000102',
  '0d000000-0000-4000-8000-000000000001',
  2,
  'Les institutions de la République',
  E'Le pouvoir exécutif est exercé par le Président de la République, à la fois chef de l''État et chef du Gouvernement. Il est élu au suffrage universel direct pour un mandat de cinq ans, renouvelable une seule fois. Cette limitation est l''un des acquis les plus commentés du texte de 1990.\n\nLe pouvoir législatif appartient à l''Assemblée nationale, chambre unique. Elle vote la loi et consent l''impôt.\n\nLe pouvoir judiciaire s''organise autour de la Cour suprême, plus haute juridiction en matière administrative, judiciaire et des comptes. À côté d''elle, deux juridictions à compétence particulière : la Cour constitutionnelle, juge de la constitutionnalité, et la Haute Cour de Justice, seule compétente pour juger le Président de la République en cas de haute trahison.\n\nDeux institutions complètent l''édifice : le Conseil Économique et Social, organe consultatif, et la Haute Autorité de l''Audiovisuel et de la Communication, qui garantit la liberté de la presse et l''accès équitable aux médias publics.',
  420
),
(
  '0d000000-0000-4000-8000-000000000103',
  '0d000000-0000-4000-8000-000000000001',
  3,
  'Le contrôle de constitutionnalité',
  E'La Cour constitutionnelle est la plus haute juridiction de l''État en matière constitutionnelle. Elle juge de la constitutionnalité de la loi et garantit les droits fondamentaux de la personne humaine et les libertés publiques.\n\nSa saisine est large, et c''est là son originalité dans la sous-région : tout citoyen peut la saisir directement, sans avoir à passer par un intermédiaire, lorsqu''il estime qu''une loi ou un acte porte atteinte à ses droits fondamentaux. Le Président de la République, les membres de l''Assemblée nationale et le Président de l''Assemblée peuvent également la saisir.\n\nLe contrôle s''exerce a priori, avant la promulgation d''une loi, comme a posteriori. Une disposition déclarée inconstitutionnelle ne peut être promulguée ni appliquée. Les décisions de la Cour ne sont susceptibles d''aucun recours et s''imposent aux pouvoirs publics comme à toutes les autorités civiles, militaires et juridictionnelles.',
  380
)
on conflict (id) do nothing;

-- Questions et fiches ------------------------------------------------------
--
-- Sous garde : les questions et les fiches n'ont pas d'identifiant fixe, un
-- rejeu de cette migration les dupliquerait. Le bloc s'abstient si le cours
-- de démonstration en porte déjà.

do $seed$
begin
  if exists (
    select 1
    from public.questions q
    join public.chapters c on c.id = q.chapter_id
    where c.course_id = '0d000000-0000-4000-8000-000000000001'
  ) then
    raise notice 'Cours de démonstration déjà garni : insertion ignorée.';
    return;
  end if;

  -- Questions — chapitre 1 ----------------------------------------------------

  insert into public.questions
    (chapter_id, type, statement, options, answer, explanation, probability) values
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'À quelle date la Constitution béninoise actuellement en vigueur a-t-elle été promulguée ?',
   '["Le 2 décembre 1990","Le 11 décembre 1990","Le 28 février 1990","Le 1er août 1960"]'::jsonb,
   'Le 11 décembre 1990',
   'Le référendum a eu lieu le 2 décembre 1990 ; la promulgation, qui donne force de loi au texte, est du 11 décembre 1990. Confondre les deux dates est l''erreur la plus fréquente.',
   'high'),
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'Quel événement ouvre la période dite du Renouveau démocratique au Bénin ?',
   '["Le coup d''État de 1972","La Conférence des Forces Vives de la Nation","L''indépendance de 1960","La révision constitutionnelle de 2019"]'::jsonb,
   'La Conférence des Forces Vives de la Nation',
   'Réunie à Cotonou en février 1990, elle met fin au régime du PRPB et ouvre la transition qui aboutit à la Constitution de décembre 1990.',
   'high'),
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'En quel mois et quelle année s''est tenue la Conférence des Forces Vives de la Nation ?',
   '["Décembre 1989","Février 1990","Décembre 1990","Mars 1991"]'::jsonb,
   'Février 1990',
   'Du 19 au 28 février 1990, à Cotonou.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'Par quel procédé la Constitution de 1990 a-t-elle été adoptée ?',
   '["Par référendum","Par vote de l''Assemblée nationale","Par ordonnance présidentielle","Par décision de la Cour suprême"]'::jsonb,
   'Par référendum',
   'L''adoption par le peuple lui-même fonde sa légitimité et explique la difficulté de sa révision.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'Quel régime politique la Constitution de 1990 met-elle en place ?',
   '["Un régime parlementaire","Un régime présidentiel","Une monarchie constitutionnelle","Un régime d''assemblée"]'::jsonb,
   'Un régime présidentiel',
   'Le Président est à la fois chef de l''État et chef du Gouvernement, sans Premier ministre dans l''architecture de 1990.',
   'high'),
  ('0d000000-0000-4000-8000-000000000101', 'open',
   'Expliquez en quoi la Conférence des Forces Vives de la Nation constitue une rupture dans l''histoire constitutionnelle béninoise.',
   null,
   'Elle met fin au régime de parti unique du PRPB, installe une transition consensuelle et débouche sur une Constitution adoptée par référendum, fondant un régime présidentiel à séparation des pouvoirs et à contrôle de constitutionnalité juridictionnel.',
   'Le plan attendu oppose l''avant — parti unique, concentration du pouvoir — et l''après — pluralisme, séparation, juge constitutionnel accessible au citoyen.',
   'high'),
  ('0d000000-0000-4000-8000-000000000101', 'mcq',
   'En quelle année la Constitution béninoise a-t-elle connu une révision notable ?',
   '["2006","2013","2019","2023"]'::jsonb,
   '2019',
   'La révision de 2019 a touché notamment le régime électoral, sans modifier l''architecture d''ensemble de 1990.',
   'low');

  -- Questions — chapitre 2 ----------------------------------------------------

  insert into public.questions
    (chapter_id, type, statement, options, answer, explanation, probability) values
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Quelle institution est seule compétente pour juger le Président de la République en cas de haute trahison ?',
   '["La Cour suprême","La Cour constitutionnelle","La Haute Cour de Justice","L''Assemblée nationale"]'::jsonb,
   'La Haute Cour de Justice',
   'La Cour constitutionnelle juge la constitutionnalité des normes, pas les personnes. La Haute Cour de Justice a cette compétence exclusive.',
   'high'),
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Quelle est la durée du mandat présidentiel ?',
   '["Quatre ans","Cinq ans","Six ans","Sept ans"]'::jsonb,
   'Cinq ans',
   'Cinq ans, renouvelable une seule fois : la limitation du nombre de mandats est un acquis central du texte de 1990.',
   'high'),
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Combien de chambres compte le Parlement béninois ?',
   '["Une seule","Deux","Trois","Le nombre varie selon la législature"]'::jsonb,
   'Une seule',
   'Le monocamérisme : l''Assemblée nationale exerce seule le pouvoir législatif.',
   'high'),
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Quelle est la plus haute juridiction en matière administrative, judiciaire et des comptes ?',
   '["La Cour constitutionnelle","La Cour suprême","La Haute Cour de Justice","La Cour d''appel de Cotonou"]'::jsonb,
   'La Cour suprême',
   'Ne pas la confondre avec la Cour constitutionnelle, qui est la plus haute juridiction en matière constitutionnelle seulement.',
   'high'),
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Quel organe garantit la liberté de la presse et l''accès équitable aux médias publics ?',
   '["Le Conseil Économique et Social","La Haute Autorité de l''Audiovisuel et de la Communication","La Cour constitutionnelle","Le Médiateur de la République"]'::jsonb,
   'La Haute Autorité de l''Audiovisuel et de la Communication',
   'La HAAC. Le Conseil Économique et Social, lui, est un organe consultatif en matière économique et sociale.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000102', 'mcq',
   'Qui exerce la fonction de chef du Gouvernement dans l''architecture de 1990 ?',
   '["Le Premier ministre","Le Président de la République","Le Président de l''Assemblée nationale","Le Président de la Cour suprême"]'::jsonb,
   'Le Président de la République',
   'Il cumule les fonctions de chef de l''État et de chef du Gouvernement, ce qui caractérise le régime présidentiel.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000102', 'open',
   'Distinguez les compétences respectives de la Cour suprême, de la Cour constitutionnelle et de la Haute Cour de Justice.',
   null,
   'La Cour suprême est la plus haute juridiction en matière administrative, judiciaire et des comptes. La Cour constitutionnelle juge la constitutionnalité des normes et garantit les droits fondamentaux. La Haute Cour de Justice juge le Président de la République en cas de haute trahison.',
   'La confusion entre ces trois juridictions est l''erreur la plus sanctionnée sur ce chapitre : chacune a une compétence exclusive, aucune n''est l''appel de l''autre.',
   'high');

  -- Questions — chapitre 3 ----------------------------------------------------

  insert into public.questions
    (chapter_id, type, statement, options, answer, explanation, probability) values
  ('0d000000-0000-4000-8000-000000000103', 'mcq',
   'Qui peut saisir directement la Cour constitutionnelle béninoise ?',
   '["Uniquement le Président de la République","Uniquement les députés","Tout citoyen","Uniquement la Cour suprême"]'::jsonb,
   'Tout citoyen',
   'C''est l''originalité du système béninois dans la sous-région : la saisine directe par le citoyen, sans intermédiaire, lorsqu''il estime ses droits fondamentaux atteints.',
   'high'),
  ('0d000000-0000-4000-8000-000000000103', 'mcq',
   'Quelle est la portée d''une décision de la Cour constitutionnelle ?',
   '["Elle est susceptible d''appel devant la Cour suprême","Elle ne lie que les parties","Elle s''impose aux pouvoirs publics et à toutes les autorités","Elle a valeur d''avis consultatif"]'::jsonb,
   'Elle s''impose aux pouvoirs publics et à toutes les autorités',
   'Aucun recours n''est ouvert contre ses décisions, qui s''imposent aux autorités civiles, militaires et juridictionnelles.',
   'high'),
  ('0d000000-0000-4000-8000-000000000103', 'mcq',
   'À quel moment le contrôle de constitutionnalité peut-il s''exercer ?',
   '["Avant la promulgation seulement","Après la promulgation seulement","Avant comme après la promulgation","Uniquement en période électorale"]'::jsonb,
   'Avant comme après la promulgation',
   'Le contrôle est à la fois a priori et a posteriori, ce qui élargit considérablement la protection des droits.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000103', 'mcq',
   'Qu''advient-il d''une disposition déclarée inconstitutionnelle ?',
   '["Elle est renvoyée à l''Assemblée pour un second vote","Elle ne peut être promulguée ni appliquée","Elle s''applique à titre transitoire","Elle est soumise à référendum"]'::jsonb,
   'Elle ne peut être promulguée ni appliquée',
   'La sanction est radicale : la disposition est écartée de l''ordre juridique.',
   'high'),
  ('0d000000-0000-4000-8000-000000000103', 'mcq',
   'Outre le contrôle des normes, quelle mission la Cour constitutionnelle assure-t-elle ?',
   '["La garantie des droits fondamentaux et des libertés publiques","La gestion du budget de l''État","La nomination des magistrats","Le contrôle des comptes publics"]'::jsonb,
   'La garantie des droits fondamentaux et des libertés publiques',
   'C''est ce qui justifie la saisine directe par le citoyen : la Cour est aussi le juge des libertés.',
   'medium'),
  ('0d000000-0000-4000-8000-000000000103', 'open',
   'En quoi la saisine directe du citoyen fait-elle l''originalité du contrôle de constitutionnalité béninois ?',
   null,
   'Elle supprime tout filtre institutionnel : le citoyen n''a pas besoin d''un relais politique ou juridictionnel pour faire valoir ses droits fondamentaux devant la Cour, ce qui transforme le juge constitutionnel en juge ordinaire des libertés et explique l''abondance de sa jurisprudence.',
   'Le plan attendu compare avec les systèmes à filtre, où seules des autorités politiques peuvent saisir, et en tire les conséquences sur l''effectivité des droits.',
   'high');

  -- Fiches de révision --------------------------------------------------------

  insert into public.flashcards (chapter_id, front, back) values
  ('0d000000-0000-4000-8000-000000000101', 'Date de promulgation de la Constitution', 'Le 11 décembre 1990. Le référendum, lui, est du 2 décembre.'),
  ('0d000000-0000-4000-8000-000000000101', 'Conférence des Forces Vives de la Nation', 'Cotonou, 19–28 février 1990. Met fin au régime du PRPB et ouvre le Renouveau démocratique.'),
  ('0d000000-0000-4000-8000-000000000101', 'Mode d''adoption', 'Par référendum, le 2 décembre 1990 — d''où sa légitimité populaire.'),
  ('0d000000-0000-4000-8000-000000000101', 'Révision notable', '2019, portant notamment sur le régime électoral.'),
  ('0d000000-0000-4000-8000-000000000102', 'Mandat présidentiel', 'Cinq ans, renouvelable une seule fois.'),
  ('0d000000-0000-4000-8000-000000000102', 'Nature du Parlement', 'Monocaméral : l''Assemblée nationale, chambre unique.'),
  ('0d000000-0000-4000-8000-000000000102', 'Haute trahison du Président', 'Compétence exclusive de la Haute Cour de Justice.'),
  ('0d000000-0000-4000-8000-000000000102', 'Cour suprême', 'Plus haute juridiction en matière administrative, judiciaire et des comptes.'),
  ('0d000000-0000-4000-8000-000000000102', 'HAAC', 'Garantit la liberté de la presse et l''accès équitable aux médias publics.'),
  ('0d000000-0000-4000-8000-000000000103', 'Saisine de la Cour constitutionnelle', 'Directe par tout citoyen, sans intermédiaire — l''originalité béninoise.'),
  ('0d000000-0000-4000-8000-000000000103', 'Autorité des décisions', 'Aucun recours possible ; elles s''imposent à toutes les autorités.'),
  ('0d000000-0000-4000-8000-000000000103', 'Moment du contrôle', 'A priori et a posteriori : avant comme après la promulgation.');

  raise notice 'Cours de démonstration : % questions, % fiches.',
    (select count(*) from public.questions q
       join public.chapters c on c.id = q.chapter_id
      where c.course_id = '0d000000-0000-4000-8000-000000000001'),
    (select count(*) from public.flashcards fl
       join public.chapters c on c.id = fl.chapter_id
      where c.course_id = '0d000000-0000-4000-8000-000000000001');
end
$seed$;
