import { describe, expect, it } from 'vitest'
import { complete, extractJson, parseUsage } from './client'
import { MODELS } from './providers'
import type { ChatMessage, ModelSpec } from './types'

/**
 * Tests du client générique.
 *
 * Ce fichier n'en avait aucun, et c'est lui qui décide ce qui part
 * réellement chez le fournisseur : trois API au format OpenAI, mais des
 * paramètres propres à chacune, dont un — `thinking` — qui fait échouer la
 * requête s'il est envoyé au mauvais endroit (docs/STACK-IA.md § 4.4).
 */

const MESSAGES: ChatMessage[] = [{ role: 'user', content: 'Bonjour.' }]

/** Capture le corps envoyé, et rend une réponse minimale exploitable. */
function banc(contenu = '{"ok":true}') {
  let corps: Record<string, unknown> = {}
  let url = ''
  let entetes: Record<string, string> = {}

  const impl = (async (u: unknown, init?: unknown) => {
    url = String(u)
    const i = init as { body: string; headers: Record<string, string> }
    corps = JSON.parse(i.body)
    entetes = i.headers
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{ message: { content: contenu } }],
        usage: { prompt_tokens: 10, completion_tokens: 5 },
      }),
    } as unknown as Response
  }) as unknown as typeof fetch

  return {
    impl,
    corps: () => corps,
    url: () => url,
    entetes: () => entetes,
  }
}

describe('paramètres propres à chaque fournisseur', () => {
  it('envoie thinking et user_id à un modèle DeepSeek de raisonnement', async () => {
    // `deepseek-v4-pro` n'est plus dans aucune route depuis que la
    // correction exige la vision, mais la mécanique reste : c'est ici
    // qu'elle est vérifiée, plutôt que dans le routage.
    const b = banc()
    await complete({
      spec: MODELS.deepseekPro as ModelSpec,
      messages: MESSAGES,
      apiKey: 'sk',
      userId: 'etudiant_123',
      fetchImpl: b.impl,
    })

    expect(b.corps().thinking).toEqual({ type: 'enabled' })
    expect(b.corps().user_id).toBe('etudiant_123')
    expect(b.corps().reasoning_effort).toBe('high')
  })

  it('n’envoie ni thinking ni user_id à GLM', async () => {
    // Les envoyer ailleurs que chez DeepSeek fait échouer la requête.
    const b = banc()
    await complete({
      spec: MODELS.glmPro as ModelSpec,
      messages: MESSAGES,
      apiKey: 'sk',
      userId: 'etudiant_123',
      fetchImpl: b.impl,
    })

    expect(b.corps().thinking).toBeUndefined()
    expect(b.corps().user_id).toBeUndefined()
    // `reasoning_effort`, en revanche, est accepté des deux côtés.
    expect(b.corps().reasoning_effort).toBe('high')
  })

  it('n’envoie pas thinking à un modèle DeepSeek qui ne le déclare pas', async () => {
    const b = banc()
    await complete({
      spec: MODELS.deepseekVision as ModelSpec,
      messages: MESSAGES,
      apiKey: 'sk',
      fetchImpl: b.impl,
    })

    expect(b.corps().thinking).toBeUndefined()
    expect(b.corps().reasoning_effort).toBeUndefined()
  })

  it('demande du JSON et pose la clé sur la bonne base', async () => {
    const b = banc()
    await complete({
      spec: MODELS.qwenVlFlash as ModelSpec,
      messages: MESSAGES,
      apiKey: 'sk-qwen',
      jsonMode: true,
      maxTokens: 1234,
      temperature: 0.4,
      fetchImpl: b.impl,
    })

    expect(b.corps().response_format).toEqual({ type: 'json_object' })
    expect(b.corps().max_tokens).toBe(1234)
    expect(b.corps().temperature).toBe(0.4)
    expect(b.url()).toContain('dashscope')
    expect(b.url()).toMatch(/\/chat\/completions$/)
    expect(b.entetes().authorization).toBe('Bearer sk-qwen')
  })
})

describe('lecture de la consommation', () => {
  it('lit le cache DeepSeek et celui des autres', () => {
    expect(
      parseUsage({
        usage: {
          prompt_tokens: 100,
          completion_tokens: 20,
          prompt_cache_hit_tokens: 40,
        },
      }).cacheHitTokens,
    ).toBe(40)

    expect(
      parseUsage({
        usage: {
          prompt_tokens: 100,
          completion_tokens: 20,
          prompt_tokens_details: { cached_tokens: 30 },
        },
      }).cacheHitTokens,
    ).toBe(30)
  })

  it('rend zéro plutôt que d’échouer sur une consommation absente', () => {
    // Une facturation approximative est moins grave qu'un job perdu.
    expect(parseUsage(null)).toEqual({
      promptTokens: 0,
      completionTokens: 0,
      cacheHitTokens: 0,
    })
    expect(parseUsage({ usage: { prompt_tokens: 'beaucoup' } }).promptTokens).toBe(0)
  })
})

describe('extraction du JSON', () => {
  it('traverse une clôture markdown', () => {
    expect(extractJson('```json\n{"a":1}\n```')).toEqual({ a: 1 })
  })

  it('traverse une phrase d’introduction', () => {
    expect(extractJson('Voici le résultat : {"a":1} — voilà.')).toEqual({ a: 1 })
  })

  it('abandonne quand il n’y a rien à lire', () => {
    expect(() => extractJson('Je ne peux pas faire cela.')).toThrow(SyntaxError)
  })
})
