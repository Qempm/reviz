import { defineConfig } from 'vitest/config'
import { resolve } from 'node:path'

export default defineConfig({
  resolve: {
    alias: { '@': resolve(import.meta.dirname, '.') },
  },
  test: {
    // Au MVP on ne teste que lib/* : pas de test d'interface (CLAUDE.md).
    include: ['lib/**/*.test.ts'],
    environment: 'node',
  },
})
