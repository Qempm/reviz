import { lireVapid } from '@/lib/notifications/webpush'

/**
 * GET /api/notifications/vapid — la clé publique du Web Push.
 *
 * L'app web en a besoin pour abonner le navigateur (`pushManager.subscribe`).
 * Publique par nature : elle ne permet que de vérifier nos envois. Lue ici
 * plutôt que compilée dans l'application, pour qu'une rotation des clés ne
 * demande pas de recompiler la version web.
 */
export function GET() {
  const vapid = lireVapid()
  if (!vapid) {
    return Response.json(
      { ok: false, error: 'Les notifications ne sont pas encore disponibles.', motif: 'non-configure' },
      { status: 503 },
    )
  }
  return Response.json({ ok: true, data: { cle: vapid.publique } })
}
