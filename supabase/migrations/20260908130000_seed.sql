-- Données initiales : 3 universités béninoises, 5 facultés chacune,
-- 4 matières par faculté, et le catalogue des 5 packs.
--
-- Migration idempotente : chaque insertion est protégée par ON CONFLICT,
-- elle peut donc être rejouée sans effet de bord.

-- Universités ---------------------------------------------------------------

insert into public.universities (code, name, city) values
  ('UAC',    'Université d''Abomey-Calavi',                                            'Abomey-Calavi'),
  ('UNSTIM', 'Université Nationale des Sciences, Technologies, Ingénierie et Mathématiques', 'Abomey'),
  ('UP',     'Université de Parakou',                                                  'Parakou')
on conflict (code) do nothing;

-- Facultés ------------------------------------------------------------------

insert into public.faculties (university_id, code, name)
select u.id, f.code, f.name
from (values
  ('UAC',    'FASEG',   'Faculté des Sciences Économiques et de Gestion'),
  ('UAC',    'FADESP',  'Faculté de Droit et de Science Politique'),
  ('UAC',    'FAST',    'Faculté des Sciences et Techniques'),
  ('UAC',    'FLASH',   'Faculté des Lettres, Arts et Sciences Humaines'),
  ('UAC',    'FSS',     'Faculté des Sciences de la Santé'),

  ('UNSTIM', 'INSTI',   'Institut National Supérieur de Technologie Industrielle'),
  ('UNSTIM', 'ENSGEP',  'École Nationale Supérieure de Génie Énergétique et Procédés'),
  ('UNSTIM', 'ENSGMM',  'École Nationale Supérieure de Génie Mathématique et Modélisation'),
  ('UNSTIM', 'ENSET',   'École Normale Supérieure de l''Enseignement Technique'),
  ('UNSTIM', 'ENSBBA',  'École Nationale Supérieure des Biosciences et Biotechnologies Appliquées'),

  ('UP',     'FASEG',   'Faculté des Sciences Économiques et de Gestion'),
  ('UP',     'FDSP',    'Faculté de Droit et de Sciences Politiques'),
  ('UP',     'FA',      'Faculté d''Agronomie'),
  ('UP',     'FM',      'Faculté de Médecine'),
  ('UP',     'FLASH',   'Faculté des Lettres, Arts et Sciences Humaines')
) as f (university_code, code, name)
join public.universities u on u.code = f.university_code
on conflict (university_id, code) do nothing;

-- Matières ------------------------------------------------------------------

insert into public.subjects (faculty_id, name, study_year)
select fa.id, s.name, s.study_year
from (values
  -- UAC
  ('UAC', 'FASEG',  'Microéconomie',                        2),
  ('UAC', 'FASEG',  'Macroéconomie',                        2),
  ('UAC', 'FASEG',  'Comptabilité générale',                1),
  ('UAC', 'FASEG',  'Statistiques descriptives',            1),

  ('UAC', 'FADESP', 'Droit constitutionnel',                1),
  ('UAC', 'FADESP', 'Droit civil des obligations',          2),
  ('UAC', 'FADESP', 'Droit administratif',                  2),
  ('UAC', 'FADESP', 'Introduction à la science politique',  1),

  ('UAC', 'FAST',   'Analyse mathématique',                 1),
  ('UAC', 'FAST',   'Chimie générale',                      1),
  ('UAC', 'FAST',   'Physique mécanique',                   1),
  ('UAC', 'FAST',   'Biologie cellulaire',                  2),

  ('UAC', 'FLASH',  'Littérature africaine',                2),
  ('UAC', 'FLASH',  'Linguistique générale',                1),
  ('UAC', 'FLASH',  'Histoire de l''Afrique précoloniale',  1),
  ('UAC', 'FLASH',  'Géographie humaine',                   2),

  ('UAC', 'FSS',    'Anatomie humaine',                     1),
  ('UAC', 'FSS',    'Physiologie',                          2),
  ('UAC', 'FSS',    'Biochimie médicale',                   2),
  ('UAC', 'FSS',    'Sémiologie médicale',                  3),

  -- UNSTIM
  ('UNSTIM', 'INSTI',  'Résistance des matériaux',          2),
  ('UNSTIM', 'INSTI',  'Électrotechnique',                  2),
  ('UNSTIM', 'INSTI',  'Dessin technique',                  1),
  ('UNSTIM', 'INSTI',  'Thermodynamique appliquée',         2),

  ('UNSTIM', 'ENSGEP', 'Transferts thermiques',             3),
  ('UNSTIM', 'ENSGEP', 'Mécanique des fluides',             2),
  ('UNSTIM', 'ENSGEP', 'Énergies renouvelables',            3),
  ('UNSTIM', 'ENSGEP', 'Génie des procédés',                3),

  ('UNSTIM', 'ENSGMM', 'Algèbre linéaire',                  1),
  ('UNSTIM', 'ENSGMM', 'Probabilités et statistiques',      2),
  ('UNSTIM', 'ENSGMM', 'Analyse numérique',                 3),
  ('UNSTIM', 'ENSGMM', 'Modélisation mathématique',         3),

  ('UNSTIM', 'ENSET',  'Pédagogie générale',                1),
  ('UNSTIM', 'ENSET',  'Didactique des sciences',           2),
  ('UNSTIM', 'ENSET',  'Technologie de l''éducation',       2),
  ('UNSTIM', 'ENSET',  'Psychologie de l''apprentissage',   1),

  ('UNSTIM', 'ENSBBA', 'Microbiologie appliquée',           2),
  ('UNSTIM', 'ENSBBA', 'Biochimie structurale',             2),
  ('UNSTIM', 'ENSBBA', 'Génie fermentaire',                 3),
  ('UNSTIM', 'ENSBBA', 'Biotechnologie végétale',           3),

  -- UP
  ('UP', 'FASEG',  'Économie générale',                     1),
  ('UP', 'FASEG',  'Comptabilité analytique',               2),
  ('UP', 'FASEG',  'Gestion financière',                    3),
  ('UP', 'FASEG',  'Marketing fondamental',                 2),

  ('UP', 'FDSP',   'Droit constitutionnel',                 1),
  ('UP', 'FDSP',   'Droit pénal général',                   2),
  ('UP', 'FDSP',   'Droit international public',            3),
  ('UP', 'FDSP',   'Institutions administratives',          1),

  ('UP', 'FA',     'Agronomie générale',                    1),
  ('UP', 'FA',     'Zootechnie',                            2),
  ('UP', 'FA',     'Phytotechnie',                          2),
  ('UP', 'FA',     'Économie rurale',                       3),

  ('UP', 'FM',     'Anatomie humaine',                      1),
  ('UP', 'FM',     'Histologie',                            1),
  ('UP', 'FM',     'Pharmacologie',                         3),
  ('UP', 'FM',     'Pathologie générale',                   3),

  ('UP', 'FLASH',  'Expression écrite et orale',            1),
  ('UP', 'FLASH',  'Sociologie générale',                   1),
  ('UP', 'FLASH',  'Histoire contemporaine',                2),
  ('UP', 'FLASH',  'Géographie du Bénin',                   2)
) as s (university_code, faculty_code, name, study_year)
join public.universities u on u.code = s.university_code
join public.faculties fa on fa.university_id = u.id and fa.code = s.faculty_code
on conflict (faculty_id, name) do nothing;

-- Packs ---------------------------------------------------------------------
--
-- Grille « accessible », arbitrée le 8 septembre 2026. CLAUDE.md fixe les
-- cinq codes mais aucun prix : ces montants sont une décision produit, pas
-- une donnée extraite. subjects_limit à NULL vaut illimité.

insert into public.packs
  (code, label, description, price_fcfa, duration_days, corrections_included, subjects_limit)
values
  ('decouverte', 'Découverte',
   'Essaie Reviz sur une matière pendant 3 jours.',
   0, 3, 1, 1),

  ('controle', 'Contrôle',
   'Une semaine pour préparer un contrôle continu sur deux matières.',
   500, 7, 3, 2),

  ('partiel', 'Partiel',
   'Un mois sur cinq matières, pour la période des partiels.',
   1500, 30, 10, 5),

  ('semestre', 'Semestre',
   'Quatre mois, toutes tes matières, sans limite.',
   3500, 120, 30, null),

  ('rattrapage', 'Rattrapage',
   'Un mois intensif sur toutes tes matières pour la session de rattrapage.',
   2000, 30, 15, null)
on conflict (code) do nothing;
