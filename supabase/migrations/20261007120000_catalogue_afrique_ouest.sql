-- Le catalogue des cinq pays (7 octobre 2026).
--
-- Jusqu'ici, trois universités béninoises. Un étudiant de Lomé, d'Abidjan,
-- de Dakar ou de Ouagadougou pouvait ajouter son école (`/api/referentiel`),
-- mais sous le nom qu'il tapait : « UL » pour l'un, « Université de Lomé »
-- pour l'autre, et deux camarades de la même promotion ne se voyaient plus au
-- classement. On pose donc les grandes universités publiques des cinq pays,
-- sous leur nom officiel suivi du sigle : « Université de Lomé (UL) ».
--
-- Le sigle entre parenthèses n'est pas décoratif : `memeNom`
-- (`lib/metier/referentiel.ts`, porté en Dart) y lit la forme courte. Taper
-- « UL », « Université de Lomé » ou le nom entier désigne la même ligne, à la
-- recherche comme à l'ajout. Les noms déjà en base reçoivent le même
-- traitement.
--
-- Les filières ne sont posées que là où leur nom est sûr. Ailleurs,
-- l'étudiant ajoute la sienne, et ses camarades la retrouvent.
--
-- Idempotente : `on conflict do nothing`, et un nom qui finit déjà par une
-- parenthèse n'est pas retouché.

-- 1. Les sigles des noms déjà en base --------------------------------------

update public.universities
set name = name || ' (' || code || ')'
where code in ('UAC', 'UNSTIM', 'UP')
  and name !~ '\)\s*$';

update public.faculties f
set name = f.name || ' (' || f.code || ')'
from public.universities u
where u.id = f.university_id
  and u.code in ('UAC', 'UNSTIM', 'UP')
  and f.name !~ '\)\s*$';

-- 2. Les universités --------------------------------------------------------

insert into public.universities (code, name, city, country_code) values
  -- Bénin
  ('UNA',    'Université Nationale d''Agriculture (UNA)',                          'Porto-Novo',     'BJ'),
  -- Togo
  ('UL',     'Université de Lomé (UL)',                                            'Lomé',           'TG'),
  ('UK',     'Université de Kara (UK)',                                            'Kara',           'TG'),
  -- Côte d'Ivoire
  ('UFHB',   'Université Félix Houphouët-Boigny (UFHB)',                           'Abidjan',        'CI'),
  ('UAO',    'Université Alassane Ouattara (UAO)',                                 'Bouaké',         'CI'),
  ('UNA-CI', 'Université Nangui Abrogoua (UNA)',                                   'Abidjan',        'CI'),
  ('UJLOG',  'Université Jean Lorougnon Guédé (UJLoG)',                            'Daloa',          'CI'),
  ('UPGC',   'Université Peleforo Gon Coulibaly (UPGC)',                           'Korhogo',        'CI'),
  ('INP-HB', 'Institut National Polytechnique Félix Houphouët-Boigny (INP-HB)',    'Yamoussoukro',   'CI'),
  ('UVCI',   'Université Virtuelle de Côte d''Ivoire (UVCI)',                      'Abidjan',        'CI'),
  -- Sénégal
  ('UCAD',   'Université Cheikh Anta Diop de Dakar (UCAD)',                        'Dakar',          'SN'),
  ('UGB',    'Université Gaston Berger (UGB)',                                     'Saint-Louis',    'SN'),
  ('UASZ',   'Université Assane Seck de Ziguinchor (UASZ)',                        'Ziguinchor',     'SN'),
  ('UADB',   'Université Alioune Diop de Bambey (UADB)',                           'Bambey',         'SN'),
  ('UIDT',   'Université Iba Der Thiam de Thiès (UIDT)',                           'Thiès',          'SN'),
  ('UNCHK',  'Université Numérique Cheikh Hamidou Kane (UN-CHK)',                  'Dakar',          'SN'),
  -- Burkina Faso
  ('UJKZ',   'Université Joseph Ki-Zerbo (UJKZ)',                                  'Ouagadougou',    'BF'),
  ('UTS',    'Université Thomas Sankara (UTS)',                                    'Ouagadougou',    'BF'),
  ('UNB',    'Université Nazi Boni (UNB)',                                         'Bobo-Dioulasso', 'BF'),
  ('UNZ',    'Université Norbert Zongo (UNZ)',                                     'Koudougou',      'BF')
on conflict (code) do nothing;

-- 3. Les filières -----------------------------------------------------------

insert into public.faculties (university_id, code, name)
select u.id, f.code, f.name
from (values
  -- UAC : les entités les plus fréquentées, en plus des cinq de départ.
  ('UAC',  'FSA',    'Faculté des Sciences Agronomiques (FSA)'),
  ('UAC',  'EPAC',   'École Polytechnique d''Abomey-Calavi (EPAC)'),
  ('UAC',  'ENEAM',  'École Nationale d''Économie Appliquée et de Management (ENEAM)'),
  ('UAC',  'FASHS',  'Faculté des Sciences Humaines et Sociales (FASHS)'),
  ('UAC',  'FLLAC',  'Faculté des Lettres, Langues, Arts et Communication (FLLAC)'),
  -- Université de Lomé
  ('UL',   'FDD',    'Faculté de Droit (FDD)'),
  ('UL',   'FASEG',  'Faculté des Sciences Économiques et de Gestion (FASEG)'),
  ('UL',   'FDS',    'Faculté des Sciences (FDS)'),
  ('UL',   'FSS',    'Faculté des Sciences de la Santé (FSS)'),
  ('UL',   'FLLA',   'Faculté des Lettres, Langues et Arts (FLLA)'),
  ('UL',   'FSHS',   'Faculté des Sciences de l''Homme et de la Société (FSHS)'),
  -- Université Félix Houphouët-Boigny
  ('UFHB', 'SJAP',   'UFR Sciences Juridiques, Administratives et Politiques (SJAP)'),
  ('UFHB', 'SEG',    'UFR Sciences Économiques et de Gestion (SEG)'),
  ('UFHB', 'SMA',    'UFR Sciences Médicales (SMA)'),
  ('UFHB', 'BIO',    'UFR Biosciences'),
  ('UFHB', 'MI',     'UFR Mathématiques et Informatique (MI)'),
  ('UFHB', 'SSMT',   'UFR Sciences des Structures de la Matière et de Technologie (SSMT)'),
  ('UFHB', 'LLC',    'UFR Langues, Littératures et Civilisations (LLC)'),
  ('UFHB', 'SHS',    'UFR Sciences de l''Homme et de la Société (SHS)'),
  -- Université Cheikh Anta Diop
  ('UCAD', 'FSJP',   'Faculté des Sciences Juridiques et Politiques (FSJP)'),
  ('UCAD', 'FASEG',  'Faculté des Sciences Économiques et de Gestion (FASEG)'),
  ('UCAD', 'FLSH',   'Faculté des Lettres et Sciences Humaines (FLSH)'),
  ('UCAD', 'FST',    'Faculté des Sciences et Techniques (FST)'),
  ('UCAD', 'FMPO',   'Faculté de Médecine, de Pharmacie et d''Odontologie (FMPO)'),
  -- Université Joseph Ki-Zerbo
  ('UJKZ', 'SEA',    'UFR Sciences Exactes et Appliquées (SEA)'),
  ('UJKZ', 'SVT',    'UFR Sciences de la Vie et de la Terre (SVT)'),
  ('UJKZ', 'SDS',    'UFR Sciences de la Santé (SDS)'),
  ('UJKZ', 'LAC',    'UFR Lettres, Arts et Communication (LAC)'),
  ('UJKZ', 'SH',     'UFR Sciences Humaines (SH)')
) as f (university_code, code, name)
join public.universities u on u.code = f.university_code
on conflict (university_id, code) do nothing;
