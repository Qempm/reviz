/**
 * Abstraction des fournisseurs de paiement Mobile Money.
 *
 * Chaque fournisseur implémente l'interface PaymentProvider : initialiser une
 * transaction, la présenter à l'utilisateur, et recevoir la confirmation via
 * webhook. FedaPay est la première implémentation (Bénin, Togo, Côte d'Ivoire) ;
 * Moneroo et KkiaPay suivront avec la même interface.
 *
 * Reference: https://fedapay.com/doc/
 */

import { z } from 'zod'

/**
 * Résultat de l'initialisation d'une transaction.
 * Le client redirige vers `redirectUrl` pour compléter le paiement.
 */
export type InitPaymentResult = {
  ok: true
  transactionId: string
  redirectUrl: string
  amount: number
  currency: 'FCFA'
} | {
  ok: false
  error: string
}

/**
 * Webhook de confirmation de paiement.
 * Le fournisseur appelle cette URL au changement de statut de la transaction.
 */
export type WebhookPayload = {
  transactionId: string
  status: 'success' | 'failed' | 'cancelled'
  amount: number
  reference?: string
  timestamp: string
}

/**
 * Interface abstraite d'un fournisseur de paiement.
 */
export interface PaymentProvider {
  /**
   * Initialiser une transaction de paiement.
   * Enregistre en base avec status='pending', retourne l'URL de redirection.
   */
  initPayment(opts: {
    userId: string
    amount: number
    packCode: string
    operator?: 'mtn' | 'moov' | 'wave'
    phone?: string
  }): Promise<InitPaymentResult>

  /**
   * Vérifier le statut d'une transaction (optionnel, pour polling).
   */
  checkStatus?(transactionId: string): Promise<{
    status: 'pending' | 'success' | 'failed' | 'cancelled'
    amount: number
  }>
}

/**
 * FedaPay implementation for West African markets.
 * https://fedapay.com/doc/
 *
 * Supports Benin (MTN, Moov), Togo (MTN, Moov), Côte d'Ivoire (Orange, MTN).
 */
class FedaPayProvider implements PaymentProvider {
  private apiKey: string
  private baseUrl: string
  private webhookSecret: string

  constructor(apiKey?: string, webhookSecret?: string) {
    this.apiKey = apiKey || process.env.FEDAPAY_SECRET_KEY || ''
    this.webhookSecret = webhookSecret || process.env.FEDAPAY_WEBHOOK_SECRET || ''
    this.baseUrl = 'https://api.fedapay.com'

    if (!this.apiKey) {
      throw new Error('FEDAPAY_SECRET_KEY missing in environment')
    }
    if (!this.webhookSecret) {
      throw new Error('FEDAPAY_WEBHOOK_SECRET missing in environment')
    }
  }

  async initPayment(opts: {
    userId: string
    amount: number
    packCode: string
    operator?: 'mtn' | 'moov' | 'wave'
    phone?: string
  }): Promise<InitPaymentResult> {
    try {
      const response = await fetch(`${this.baseUrl}/v1/transactions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          amount: opts.amount,
          currency: 'FCFA',
          description: `Reviz pack ${opts.packCode}`,
          customer: {
            phone: opts.phone || '',
          },
          metadata: {
            user_id: opts.userId,
            pack_code: opts.packCode,
          },
          callback_url: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/webhook`,
          return_url: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/paiement/en-cours`,
        }),
      })

      if (!response.ok) {
        const error = await response.json().catch(() => ({}))
        return {
          ok: false,
          error: error.message || `FedaPay returned ${response.status}`,
        }
      }

      const data = (await response.json()) as {
        transaction?: {
          id: string | number
          token?: string
        }
        data?: {
          id: string | number
          token?: string
        }
      }

      // FedaPay wraps response in `data`
      const tx = (data.data || data.transaction) as {
        id: string | number
        token?: string
      } | undefined

      if (!tx?.id) {
        return {
          ok: false,
          error: 'Invalid FedaPay response: no transaction ID',
        }
      }

      const redirectUrl = `${this.baseUrl}/checkout/${tx.id}${tx.token ? `?token=${tx.token}` : ''}`

      return {
        ok: true,
        transactionId: String(tx.id),
        redirectUrl,
        amount: opts.amount,
        currency: 'FCFA',
      }
    } catch (error) {
      console.error('FedaPay initPayment error:', error)
      return {
        ok: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }
    }
  }

  /**
   * Verify webhook signature using HMAC-SHA256.
   * FedaPay sends the signature in X-Fedapay-Signature header.
   */
  verifyWebhookSignature(payload: string, signature: string): boolean {
    const crypto = require('crypto')
    const computed = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(payload)
      .digest('hex')
    return computed === signature
  }
}

/**
 * Factory to get the appropriate payment provider.
 * Currently only FedaPay is implemented.
 */
export function createPaymentProvider(
  provider: string = 'fedapay',
): PaymentProvider {
  switch (provider.toLowerCase()) {
    case 'fedapay':
      return new FedaPayProvider()
    default:
      throw new Error(`Unknown payment provider: ${provider}`)
  }
}

export { FedaPayProvider }

/**
 * Validate a webhook signature.
 * Use this in your webhook route before processing the payload.
 */
export function validateWebhookSignature(
  payload: string,
  signature: string,
  secret: string,
): boolean {
  const crypto = require('crypto')
  const computed = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex')
  return computed === signature
}
