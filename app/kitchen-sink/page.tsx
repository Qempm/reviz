'use client'

import { useState } from 'react'
import {
  BottomNav,
  Button,
  Card,
  EmptyState,
  HeroCard,
  Icon,
  LeaderboardRow,
  MascotState,
  Podium,
  ProgressBar,
  QuizOption,
  SegmentedProgressBar,
  StreakCard,
  Toast,
} from '@/components/ui'
import type { MascotMood, QuizOptionState, SegmentState } from '@/components/ui'

/**
 * Page de validation visuelle du design system.
 *
 * Elle affiche les 11 composants de CLAUDE.md dans tous leurs états, pour
 * comparaison avec les maquettes Stitch avant de construire les écrans
 * métier. Ce n'est pas un écran du produit : elle n'est pas listée dans la
 * navigation et n'a pas vocation à survivre au MVP.
 */

function Section({
  titre,
  reference,
  children,
}: {
  titre: string
  /** Renvoi vers le paragraphe de docs/DESIGN.md qui fait foi. */
  reference: string
  children: React.ReactNode
}) {
  return (
    <section className="flex flex-col gap-space-12">
      <div className="flex items-baseline justify-between gap-space-8">
        <h2 className="text-headline-lg text-reviz-ink">{titre}</h2>
        <span className="shrink-0 text-caption uppercase text-reviz-muted">
          {reference}
        </span>
      </div>
      {children}
    </section>
  )
}

const SEMAINE = [
  { weekday: 1, isValidated: true, isToday: false },
  { weekday: 2, isValidated: true, isToday: false },
  { weekday: 3, isValidated: true, isToday: false },
  { weekday: 4, isValidated: true, isToday: false },
  { weekday: 5, isValidated: false, isToday: true },
  { weekday: 6, isValidated: false, isToday: false },
  { weekday: 7, isValidated: false, isToday: false },
]

const SEGMENTS: SegmentState[] = [
  'correct',
  'correct',
  'wrong',
  'correct',
  'upcoming',
  'upcoming',
]

const MOODS: MascotMood[] = [
  'accueil',
  'reussite',
  'echec',
  'chargement',
  'pack-expire',
]

export default function KitchenSink() {
  const [choix, setChoix] = useState<number | null>(1)
  const [correction, setCorrection] = useState(false)

  const etatOption = (i: number): QuizOptionState => {
    if (correction) {
      if (i === 2) return 'correct'
      if (i === choix) return 'wrong'
      return 'idle'
    }
    return i === choix ? 'selected' : 'idle'
  }

  return (
    <div className="mx-auto min-h-screen w-full max-w-app px-screen-margin-mobile pb-[128px] pt-space-24">
      <header className="mb-space-24 flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">Kitchen-sink</h1>
        <p className="text-body-md text-reviz-muted">
          Les 11 composants du design system, dans tous leurs états. Référence :{' '}
          <span className="text-reviz-ink">docs/DESIGN.md</span>.
        </p>
      </header>

      <div className="flex flex-col gap-space-32">
        {/* Palette ---------------------------------------------------------- */}
        <Section titre="Palette" reference="§ 2">
          <div className="grid grid-cols-2 gap-space-8">
            {[
              ['Fond', 'bg-reviz-cream border border-reviz-border', '#fcf9f8'],
              ['Carte', 'bg-reviz-card border border-reviz-border', '#ffffff'],
              ['Jaune', 'bg-reviz-yellow', '#ffc300'],
              ['Jaune pâle', 'bg-reviz-yellow-soft', '#ffdf9a'],
              ['Orange', 'bg-reviz-orange', '#fe6a2b'],
              ['Pêche', 'bg-reviz-orange-soft', '#ffdbcf'],
              ['Bleu', 'bg-reviz-blue', '#bccdeb'],
              ['Bleu clair', 'bg-reviz-blue-soft', '#d4e3ff'],
              ['Erreur', 'bg-reviz-danger', '#ba1a1a'],
              ['Erreur pâle', 'bg-reviz-danger-soft', '#ffdad6'],
              ['Encre', 'bg-reviz-ink', '#1c1b1b'],
              ['Texte doux', 'bg-reviz-muted', '#4f4632'],
            ].map(([nom, classe, hex]) => (
              <div key={nom} className="flex items-center gap-space-8">
                <span className={`h-10 w-10 shrink-0 rounded-xl ${classe}`} />
                <span className="flex flex-col">
                  <span className="text-label-md text-reviz-ink">{nom}</span>
                  <span className="text-caption text-reviz-muted">{hex}</span>
                </span>
              </div>
            ))}
          </div>
        </Section>

        {/* Typographie ------------------------------------------------------ */}
        <Section titre="Typographie" reference="§ 3">
          <Card>
            <span className="text-display-hero text-reviz-ink">4 200</span>
            <span className="text-display-hero-mobile text-reviz-ink">
              1 280 XP
            </span>
            <span className="text-headline-xl text-reviz-ink">Titre d’écran</span>
            <span className="text-headline-lg text-reviz-ink">Titre de section</span>
            <span className="text-headline-md text-reviz-ink">Titre de carte</span>
            <span className="text-headline-sm text-reviz-ink">Sous-titre</span>
            <span className="text-body-lg text-reviz-ink">
              Corps de texte large, pour les énoncés de questions.
            </span>
            <span className="text-body-md text-reviz-muted">
              Corps courant, 15 px, utilisé partout ailleurs.
            </span>
            <span className="text-label-lg text-reviz-ink">Label large</span>
            <span className="text-label-md text-reviz-ink">Label moyen</span>
            <span className="text-label-sm text-reviz-muted">Label petit</span>
            <span className="text-caption uppercase text-reviz-muted">
              Légende en majuscules
            </span>
          </Card>
        </Section>

        {/* Boutons ---------------------------------------------------------- */}
        <Section titre="Button" reference="§ 7">
          <div className="flex flex-col gap-space-12">
            <Button icon="bolt">Commencer la révision</Button>
            <Button variant="secondary" icon="upload_file">
              Ajouter un cours
            </Button>
            <Button variant="danger" icon="delete">
              Supprimer mon compte
            </Button>
            <Button disabled>Indisponible</Button>
            <div className="flex items-center gap-space-12">
              <Button variant="fab" icon="add" aria-label="Ajouter" />
              <span className="text-label-sm text-reviz-muted">
                Appuie sur un bouton : l’arête tactile se réduit de 4 px à 2 px.
              </span>
            </div>
          </div>
        </Section>

        {/* Cartes ----------------------------------------------------------- */}
        <Section titre="Card" reference="§ 7">
          <Card>
            <h3 className="text-headline-md text-reviz-ink">Carte standard</h3>
            <p className="text-body-md text-reviz-muted">
              Rayon 20 px, 20 px de gouttière, ombre douce, sans bordure.
            </p>
          </Card>
          <Card size="sm">
            <h3 className="text-headline-sm text-reviz-ink">Encart interne</h3>
            <p className="text-label-sm text-reviz-muted">
              Rayon 12 px, 12 px de gouttière.
            </p>
          </Card>
        </Section>

        {/* Progression ------------------------------------------------------ */}
        <Section titre="ProgressBar" reference="§ 7">
          <Card>
            <ProgressBar value={0.78} label="Microéconomie" />
            <ProgressBar value={0.24} label="Droit constitutionnel" />
            <ProgressBar value={1} label="Statistiques" />
            <div className="flex flex-col gap-space-8 pt-space-8">
              <span className="text-label-sm text-reviz-muted">
                Session de QCM en cours
              </span>
              <SegmentedProgressBar segments={SEGMENTS} />
            </div>
          </Card>
        </Section>

        {/* Carte héros ------------------------------------------------------ */}
        <Section titre="HeroCard" reference="§ 7">
          <HeroCard
            badge="J-3 avant le contrôle"
            meta="Amphi 7 • 08:30"
            title="Contrôle continu : Droit constitutionnel"
            subtitle="42 chapitres • 180 questions probables"
            watermark="gavel"
            avatars={['A', 'M', 'K', 'S']}
            avatarsLabel="+1 420 candidats"
          />
        </Section>

        {/* Streak ----------------------------------------------------------- */}
        <Section titre="StreakCard" reference="§ 7">
          <StreakCard
            streak={4}
            xpToday={120}
            days={SEMAINE}
            message="Plus qu’un jour pour débloquer le badge Flamme d’Abidjan."
          />
        </Section>

        {/* Podium ----------------------------------------------------------- */}
        <Section titre="Podium" reference="§ 7">
          <Card>
            <Podium
              first={{ name: 'Aminata', xp: 4820 }}
              second={{ name: 'Moussa', xp: 4310 }}
              third={{ name: 'Kofi', xp: 3990 }}
            />
            <div className="flex flex-col gap-space-8">
              <LeaderboardRow rank={4} entry={{ name: 'Sarah', xp: 3120 }} />
              <LeaderboardRow
                rank={5}
                entry={{ name: 'Toi', xp: 2870 }}
                isCurrentUser
              />
            </div>
          </Card>
        </Section>

        {/* QCM -------------------------------------------------------------- */}
        <Section titre="QuizOption" reference="§ 7">
          <Card>
            <p className="text-body-lg text-reviz-ink">
              Quel organe contrôle la constitutionnalité des lois au Bénin ?
            </p>
            <div className="flex flex-col gap-space-12">
              {[
                'La Cour suprême',
                'L’Assemblée nationale',
                'La Cour constitutionnelle',
                'Le Conseil économique et social',
              ].map((label, i) => (
                <QuizOption
                  key={i}
                  letter={['A', 'B', 'C', 'D'][i]}
                  label={label}
                  state={etatOption(i)}
                  onSelect={() => !correction && setChoix(i)}
                />
              ))}
            </div>
            <Button
              variant={correction ? 'secondary' : 'primary'}
              onClick={() => setCorrection((v) => !v)}
            >
              {correction ? 'Réinitialiser' : 'Valider ma réponse'}
            </Button>
            <p className="text-label-sm text-reviz-muted">
              Aucun vert : la bonne réponse est en jaune, la mauvaise en rouge
              d’erreur (§ 11).
            </p>
          </Card>
        </Section>

        {/* Toasts ----------------------------------------------------------- */}
        <Section titre="Toast" reference="§ 7">
          <div className="flex flex-col items-start gap-space-12">
            <Toast message="Cours ajouté, traitement en cours" />
            <Toast message="+120 XP gagnés" tone="success" />
            <Toast message="Paiement refusé par l’opérateur" tone="danger" />
          </div>
        </Section>

        {/* États vides ------------------------------------------------------ */}
        <Section titre="EmptyState" reference="§ 7">
          <Card>
            <EmptyState
              icon="menu_book"
              title="Aucune matière pour l’instant"
              description="Ajoute ton premier cours et Reviz en tire des QCM et des fiches."
              action={<Button icon="add">Ajouter un cours</Button>}
            />
          </Card>
        </Section>

        {/* Mascotte --------------------------------------------------------- */}
        <Section titre="MascotState" reference="§ 9">
          <Card>
            <p className="text-label-sm text-reviz-muted">
              Les visuels de <code>public/mascotte/</code> n’existent pas encore :
              Stitch n’a livré aucun asset local. Les pastilles ci-dessous sont le
              repli affiché en leur absence.
            </p>
            <div className="grid grid-cols-2 gap-space-20 pt-space-8">
              {MOODS.map((mood) => (
                <MascotState key={mood} mood={mood} size={72} />
              ))}
            </div>
          </Card>
        </Section>

        {/* Navigation ------------------------------------------------------- */}
        <Section titre="BottomNav" reference="§ 7">
          <Card>
            <p className="text-label-sm text-reviz-muted">
              Fixée en bas de cette page. Onglet actif en pilule jaune, barre
              plate à 80 px — variante arbitrée au § 11.
            </p>
            <div className="flex items-center gap-space-8 text-label-sm text-reviz-muted">
              <Icon name="arrow_downward" size={18} />
              Regarde le bas de l’écran.
            </div>
          </Card>
        </Section>
      </div>

      <BottomNav active="/" />
    </div>
  )
}
