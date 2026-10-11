import Anthropic from '@anthropic-ai/sdk'
import {
  EmptyContentError,
  HttpError,
  type CompletionOptions,
  type CompletionResult,
} from './client'
import type { ChatMessage, ContentPart, EffortClaude, TokenUsage } from './types'

/**
 * Client Claude (Anthropic), au même contrat que `complete()` : mêmes
 * options, même résultat. La chaîne de secours (`routing.ts`) ne voit pas la
 * différence entre un fournisseur au format OpenAI et Claude.
 *
 * Claude Haiku 5.5 a ses règles (docs/STACK-IA.md § 5) :
 * - pas de `temperature`, `top_p` ni `top_k` : ils sont refusés (400). Le
 *   seul levier de dépense est l'effort (`output_config.effort`) ;
 * - la réflexion adaptative est active par défaut : la réponse peut commencer
 *   par des blocs `thinking`. On lit donc les blocs `text`, jamais le premier
 *   bloc ;
 * - pas de préremplissage : la conversation finit toujours par l'étudiant ;
 * - un refus de sécurité (`stop_reason: "refusal"`) n'a pas de secours côté
 *   serveur pour ce modèle : il lève, et la chaîne passe au fournisseur
 *   suivant.
 *
 * Le bloc `system` (consignes et texte du cours) est marqué pour le cache :
 * d'un tour du tuteur à l'autre, il est relu à 0,1 fois le prix.
 */

export type OptionsClaude = CompletionOptions & { effort?: EffortClaude }

/** Le message `system` de nos conversations, en blocs mis en cache. */
function systeme(messages: ChatMessage[]): Anthropic.TextBlockParam[] | undefined {
  const textes = messages
    .filter((m) => m.role === 'system')
    .map((m) =>
      typeof m.content === 'string'
        ? m.content
        : m.content
            .filter((p): p is Extract<ContentPart, { type: 'text' }> => p.type === 'text')
            .map((p) => p.text)
            .join('\n'),
    )
    .filter((t) => t.trim() !== '')
  if (textes.length === 0) return undefined
  return [{ type: 'text', text: textes.join('\n\n'), cache_control: { type: 'ephemeral' } }]
}

/** Une image : URL signée du stockage, ou `data:` en base64. */
function image(url: string): Anthropic.ImageBlockParam {
  const data = /^data:(image\/(?:jpeg|png|gif|webp));base64,(.+)$/i.exec(url)
  if (data) {
    return {
      type: 'image',
      source: {
        type: 'base64',
        media_type: data[1].toLowerCase() as 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp',
        data: data[2],
      },
    }
  }
  return { type: 'image', source: { type: 'url', url } }
}

/** Nos messages au format Anthropic, sans le `system`. */
export function versClaude(messages: ChatMessage[]): {
  system?: Anthropic.TextBlockParam[]
  messages: Anthropic.MessageParam[]
} {
  const corps: Anthropic.MessageParam[] = messages
    .filter((m) => m.role !== 'system')
    .map((m) => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content:
        typeof m.content === 'string'
          ? m.content
          : m.content.map((p): Anthropic.ContentBlockParam =>
              p.type === 'text' ? { type: 'text', text: p.text } : image(p.image_url.url),
            ),
    }))
  return { system: systeme(messages), messages: corps }
}

/** La consommation, dans nos termes : les jetons en cache font partie du prompt. */
export function usageClaude(u: Anthropic.Usage | undefined): TokenUsage {
  const n = (v: number | null | undefined) =>
    typeof v === 'number' && Number.isFinite(v) && v >= 0 ? Math.round(v) : 0
  if (!u) return { promptTokens: 0, completionTokens: 0, cacheHitTokens: 0 }
  const lus = n(u.cache_read_input_tokens)
  return {
    promptTokens: n(u.input_tokens) + lus + n(u.cache_creation_input_tokens),
    completionTokens: n(u.output_tokens),
    cacheHitTokens: lus,
  }
}

/** Le texte de la réponse : les blocs `text`, après les éventuels `thinking`. */
export function texteClaude(message: Anthropic.Message): string {
  return message.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('')
}

export async function completeAnthropic(opts: OptionsClaude): Promise<CompletionResult> {
  const client = new Anthropic({
    apiKey: opts.apiKey,
    // La chaîne de secours réessaie elle-même : pas de seconde boucle ici.
    maxRetries: 0,
    ...(opts.fetchImpl ? { fetch: opts.fetchImpl } : {}),
  })
  const { system, messages } = versClaude(opts.messages)

  let reponse: Anthropic.Message
  try {
    reponse = await client.messages.create(
      {
        model: opts.spec.model,
        // La réflexion compte dans `max_tokens` : de la place, sinon la
        // réponse s'arrête avant le JSON.
        max_tokens: opts.maxTokens ?? 8000,
        ...(system ? { system } : {}),
        messages,
        output_config: { effort: opts.effort ?? 'low' },
      },
      { signal: opts.signal },
    )
  } catch (e) {
    // Les erreurs HTTP du SDK deviennent les nôtres : un 429 se réessaie
    // chez le même fournisseur, le reste fait basculer.
    if (e instanceof Anthropic.APIError && typeof e.status === 'number') {
      throw new HttpError(e.status, e.message)
    }
    throw e
  }

  const usage = usageClaude(reponse.usage)

  if (reponse.stop_reason === 'refusal') {
    throw Object.assign(new Error('Claude a refusé la demande.'), { usage })
  }
  if (reponse.stop_reason === 'max_tokens') {
    throw Object.assign(new Error('Réponse de Claude tronquée (max_tokens).'), { usage })
  }

  const content = texteClaude(reponse)
  if (content.trim() === '') throw new EmptyContentError()

  return { content, usage, raw: reponse }
}
