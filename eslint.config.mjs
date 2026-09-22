import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { FlatCompat } from '@eslint/eslintrc'

// Configuration ESLint du projet.
//
// Elle n'existait pas : `npm run lint` échouait sur « ESLint couldn't find an
// eslint.config.js file » — ESLint 9 n'accepte plus l'ancien format, et aucun
// `.eslintrc` n'avait été écrit. Le script était donc rouge depuis le premier
// jour, sans que personne le voie puisque aucun workflow ne l'exécutait.
//
// `FlatCompat` sert à consommer `eslint-config-next`, encore publié à l'ancien
// format. C'est la voie que Next.js documente lui-même.

const compat = new FlatCompat({
  baseDirectory: dirname(fileURLToPath(import.meta.url)),
})

const configuration = [
  {
    ignores: [
      '.next/**',
      'node_modules/**',
      'out/**',
      'coverage/**',
      '.vitest/**',
      // Fichier généré par `supabase gen types` : le corriger à la main
      // serait écrasé au prochain `npm run db:types`.
      'lib/supabase/database.types.ts',
      // Projets d'un autre écosystème, avec leurs propres outils :
      // `flutter analyze` pour l'un, Gradle et ktlint pour l'autre.
      'apps/**',
      // Écrit par Next.js à chaque build.
      'next-env.d.ts',
    ],
  },
  ...compat.extends('next/core-web-vitals', 'next/typescript'),
  {
    rules: {
      // Les apostrophes et guillemets français sont partout dans les textes
      // d'interface : la règle ne garde que sa part utile, les caractères
      // qu'on ne peut vraiment pas laisser nus dans du JSX.
      'react/no-unescaped-entities': ['error', { forbid: ['>', '}'] }],

      // Le préfixe `_` marque un paramètre volontairement ignoré — courant
      // dans les signatures imposées (gestionnaires de route, callbacks).
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
]

export default configuration
