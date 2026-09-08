import type { Config } from 'tailwindcss'

/**
 * Design system Reviz — figé depuis le projet Stitch 4246361917454252874.
 *
 * Source de vérité : docs/DESIGN.md. Les valeurs ci-dessous sont celles que
 * Stitch compile réellement dans ses écrans, pas celles recopiées dans
 * CLAUDE.md (voir docs/DESIGN.md § 10 pour la liste des écarts).
 *
 * Deux jeux de tokens cohabitent volontairement :
 *
 *  1. Les rôles Material 3 (`surface`, `primary-container`, `on-surface`, …).
 *     Ils permettent de coller le markup exporté de Stitch sans le réécrire.
 *  2. Les alias métier `reviz.*` exigés par CLAUDE.md, qui pointent vers les
 *     mêmes valeurs. À privilégier dans le code qu'on écrit nous-mêmes.
 */

/** Palette brute, partagée par les deux jeux de tokens. */
const stitch = {
  // Surfaces
  surface: '#fcf9f8',
  surfaceDim: '#dcd9d9',
  surfaceBright: '#fcf9f8',
  surfaceContainerLowest: '#ffffff',
  surfaceContainerLow: '#f6f3f2',
  surfaceContainer: '#f0eded',
  surfaceContainerHigh: '#eae7e7',
  surfaceContainerHighest: '#e5e2e1',
  surfaceVariant: '#e5e2e1',
  surfaceTint: '#785a00',
  onSurface: '#1c1b1b',
  onSurfaceVariant: '#4f4632',
  inverseSurface: '#313030',
  inverseOnSurface: '#f3f0ef',
  outline: '#81765f',
  outlineVariant: '#d3c5ab',

  // Jaune
  primary: '#785a00',
  onPrimary: '#ffffff',
  primaryContainer: '#ffc300',
  onPrimaryContainer: '#6d5200',
  primaryFixed: '#ffdf9a',
  primaryFixedDim: '#f8be00',
  onPrimaryFixed: '#251a00',
  onPrimaryFixedVariant: '#5a4300',
  inversePrimary: '#f8be00',

  // Orange
  secondary: '#a83900',
  onSecondary: '#ffffff',
  secondaryContainer: '#fe6a2b',
  onSecondaryContainer: '#5b1b00',
  secondaryFixed: '#ffdbcf',
  secondaryFixedDim: '#ffb59a',
  onSecondaryFixed: '#380d00',
  onSecondaryFixedVariant: '#802900',

  // Bleu
  tertiary: '#4f5f79',
  onTertiary: '#ffffff',
  tertiaryContainer: '#bccdeb',
  onTertiaryContainer: '#475771',
  tertiaryFixed: '#d4e3ff',
  tertiaryFixedDim: '#b6c7e6',
  onTertiaryFixed: '#0a1c33',
  onTertiaryFixedVariant: '#374760',

  // Erreur
  error: '#ba1a1a',
  onError: '#ffffff',
  errorContainer: '#ffdad6',
  onErrorContainer: '#93000a',

  // Arêtes tactiles (ombres pleines sans flou)
  edgeYellow: '#d9a400',
  edgeOrange: '#d94e15',
  edgeNeutral: '#d3c5ab',
  edgePeach: '#802900',
  edgeError: '#93000a',
} as const

/** Marques tierces, hors design system — écrans Mobile Money et WhatsApp. */
const brands = {
  mtn: '#FFCC00',
  orange: '#FF7900',
  moov: '#00D2FF',
  moovDark: '#006699',
  whatsapp: '#25D366',
  whatsappDark: '#1EBE5B',
  whatsappDeep: '#128C7E',
} as const

const config: Config = {
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './lib/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // --- 1. Rôles Material 3 émis par Stitch -------------------------
        // Permettent de coller le markup Stitch tel quel.
        surface: stitch.surface,
        'surface-dim': stitch.surfaceDim,
        'surface-bright': stitch.surfaceBright,
        'surface-container-lowest': stitch.surfaceContainerLowest,
        'surface-container-low': stitch.surfaceContainerLow,
        'surface-container': stitch.surfaceContainer,
        'surface-container-high': stitch.surfaceContainerHigh,
        'surface-container-highest': stitch.surfaceContainerHighest,
        'surface-variant': stitch.surfaceVariant,
        'surface-tint': stitch.surfaceTint,
        'on-surface': stitch.onSurface,
        'on-surface-variant': stitch.onSurfaceVariant,
        'inverse-surface': stitch.inverseSurface,
        'inverse-on-surface': stitch.inverseOnSurface,
        outline: stitch.outline,
        'outline-variant': stitch.outlineVariant,
        background: stitch.surface,
        'on-background': stitch.onSurface,

        primary: stitch.primary,
        'on-primary': stitch.onPrimary,
        'primary-container': stitch.primaryContainer,
        'on-primary-container': stitch.onPrimaryContainer,
        'primary-fixed': stitch.primaryFixed,
        'primary-fixed-dim': stitch.primaryFixedDim,
        'on-primary-fixed': stitch.onPrimaryFixed,
        'on-primary-fixed-variant': stitch.onPrimaryFixedVariant,
        'inverse-primary': stitch.inversePrimary,

        secondary: stitch.secondary,
        'on-secondary': stitch.onSecondary,
        'secondary-container': stitch.secondaryContainer,
        'on-secondary-container': stitch.onSecondaryContainer,
        'secondary-fixed': stitch.secondaryFixed,
        'secondary-fixed-dim': stitch.secondaryFixedDim,
        'on-secondary-fixed': stitch.onSecondaryFixed,
        'on-secondary-fixed-variant': stitch.onSecondaryFixedVariant,

        tertiary: stitch.tertiary,
        'on-tertiary': stitch.onTertiary,
        'tertiary-container': stitch.tertiaryContainer,
        'on-tertiary-container': stitch.onTertiaryContainer,
        'tertiary-fixed': stitch.tertiaryFixed,
        'tertiary-fixed-dim': stitch.tertiaryFixedDim,
        'on-tertiary-fixed': stitch.onTertiaryFixed,
        'on-tertiary-fixed-variant': stitch.onTertiaryFixedVariant,

        error: stitch.error,
        'on-error': stitch.onError,
        'error-container': stitch.errorContainer,
        'on-error-container': stitch.onErrorContainer,

        // --- 2. Alias métier reviz.* (contrat CLAUDE.md) -----------------
        reviz: {
          /**
           * Fond de page. CLAUDE.md annonce un crème #FFF8E7 : il n'existe
           * dans aucun écran Stitch. Arbitré le 08/09/2026 en faveur de la
           * valeur Stitch (docs/DESIGN.md § 11) — ne pas « corriger » vers
           * #FFF8E7 sans nouvelle décision.
           */
          cream: stitch.surface,
          /** Jaune Reviz : fond des CTA, progression, podium n°1. */
          yellow: stitch.primaryContainer,
          /** Orange Reviz : urgence, compte à rebours, streak du jour. */
          orange: stitch.secondaryContainer,
          /** Bleu doux : podium n°2, badges. */
          blue: stitch.tertiaryContainer,
          /** Encre : tout le texte principal. */
          ink: stitch.onSurface,
          /** Texte secondaire — brun chaud, jamais un gris froid. */
          muted: stitch.onSurfaceVariant,

          // Compléments indispensables, absents de CLAUDE.md
          /** Surface des cartes. */
          card: stitch.surfaceContainerLowest,
          /** Jaune pâle : option QCM sélectionnée. */
          'yellow-soft': stitch.primaryFixed,
          /** Pêche pâle : podium n°3. */
          'orange-soft': stitch.secondaryFixed,
          /** Bleu très clair : fonds d'encarts. */
          'blue-soft': stitch.tertiaryFixed,
          /** Texte et icônes posés sur le jaune. */
          'on-yellow': stitch.onPrimaryContainer,
          /**
           * Rouge d'erreur / mauvaise réponse.
           * Il n'existe volontairement AUCUN token de succès vert : une bonne
           * réponse se célèbre en jaune. Arbitré le 08/09/2026
           * (docs/DESIGN.md § 11). Ne pas ajouter #22C55E ni #EF4444.
           */
          danger: stitch.error,
          'danger-soft': stitch.errorContainer,
          'on-danger-soft': stitch.onErrorContainer,
          /** Bordures et séparateurs. */
          border: stitch.outlineVariant,
          /** Arêtes tactiles des boutons poussoirs. */
          edge: {
            yellow: stitch.edgeYellow,
            orange: stitch.edgeOrange,
            neutral: stitch.edgeNeutral,
            peach: stitch.edgePeach,
            danger: stitch.edgeError,
          },
        },

        brand: brands,
      },

      fontFamily: {
        // Nunito Sans — et non Nunito (voir docs/DESIGN.md § 10, écart 2).
        sans: ['var(--font-nunito-sans)', 'Nunito Sans', 'system-ui', 'sans-serif'],
      },

      fontSize: {
        'display-hero': ['44px', { lineHeight: '48px', letterSpacing: '-0.02em', fontWeight: '800' }],
        'display-hero-mobile': ['38px', { lineHeight: '42px', letterSpacing: '-0.02em', fontWeight: '800' }],
        'headline-xl': ['28px', { lineHeight: '34px', letterSpacing: '-0.015em', fontWeight: '800' }],
        'headline-lg': ['22px', { lineHeight: '28px', letterSpacing: '-0.01em', fontWeight: '800' }],
        'headline-md': ['18px', { lineHeight: '24px', fontWeight: '800' }],
        'headline-sm': ['16px', { lineHeight: '22px', fontWeight: '700' }],
        'body-lg': ['16px', { lineHeight: '24px', fontWeight: '500' }],
        'body-md': ['15px', { lineHeight: '22px', fontWeight: '500' }],
        'label-lg': ['16px', { lineHeight: '20px', fontWeight: '700' }],
        'label-md': ['14px', { lineHeight: '18px', fontWeight: '700' }],
        'label-sm': ['13px', { lineHeight: '16px', fontWeight: '600' }],
        caption: ['11px', { lineHeight: '14px', letterSpacing: '0.04em', fontWeight: '700' }],
      },

      spacing: {
        'space-2': '0.125rem',
        'space-4': '0.25rem',
        'space-8': '0.5rem',
        'space-12': '0.75rem',
        'space-16': '1rem',
        'space-20': '1.25rem',
        'space-24': '1.5rem',
        'space-32': '2rem',
        'space-40': '2.5rem',
        'space-48': '3rem',
        'screen-margin-mobile': '1rem',
        'screen-margin-tablet': '1.5rem',
      },

      borderRadius: {
        // Échelle réellement compilée par Stitch (ROUND_EIGHT).
        // Ne PAS reprendre celle du front-matter de son designMd :
        // les deux diffèrent (docs/DESIGN.md § 5).
        DEFAULT: '0.25rem', //  4px
        lg: '0.5rem', //  8px
        xl: '0.75rem', // 12px — rayon dominant des composants
        // 2xl (16px) et 3xl (24px) restent aux défauts Tailwind, utilisés tels quels.

        // Rayons littéraux des grandes surfaces, nommés pour éviter les
        // valeurs arbitraires `rounded-[20px]` disséminées dans le code.
        card: '20px',
        hero: '24px',
        sheet: '28px',
      },

      boxShadow: {
        // Ombres d'ambiance
        header: '0 4px 20px rgba(26,26,26,0.04)',
        card: '0 4px 20px rgba(26,26,26,0.06)',
        'card-sm': '0 4px 16px rgba(26,26,26,0.05)',
        float: '0 8px 24px rgba(26,26,26,0.06)',
        hero: '0 8px 24px rgba(254,106,43,0.22)',
        'glow-yellow': '0 8px 24px rgba(255,195,0,0.15)',
        'glow-yellow-sm': '0 2px 6px rgba(255,195,0,0.3)',
        nav: '0 -8px 32px rgba(26,26,26,0.06)',
        'card-danger': '0 4px 14px rgba(186,26,26,0.08)',

        // Arêtes tactiles — état au repos puis état pressé
        tactile: `0 4px 0 ${stitch.edgeYellow}`,
        'tactile-pressed': `0 2px 0 ${stitch.edgeYellow}`,
        'tactile-sm': `0 2px 0 ${stitch.edgeYellow}`,
        'tactile-orange': `0 4px 0 ${stitch.edgeOrange}`,
        'tactile-orange-pressed': `0 2px 0 ${stitch.edgeOrange}`,
        'tactile-neutral': `0 2px 0 ${stitch.edgeNeutral}`,
        'tactile-danger': `0 4px 0 ${stitch.edgeError}`,
      },

      height: {
        header: '4rem', // 64px
        nav: '5rem', // 80px — barre plate, onglet actif en pilule jaune (§ 11)
        cta: '3.5rem', // 56px — variante A du CTA, canonique (§ 11)
      },

      maxWidth: {
        // Le shell reste centré sur une largeur mobile au-delà du téléphone.
        app: '440px',
      },
    },
  },
  plugins: [],
}

export default config
