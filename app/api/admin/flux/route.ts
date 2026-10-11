import { adminConnecte, lirePaiements, lireTableau } from '@/lib/admin/serveur'

/**
 * GET /api/admin/flux → `{ tableau, paiements }`
 *
 * Ce que la page d'administration relit toutes les 15 s. Vérifie elle-même
 * la session et ADMIN_EMAILS : une route n'hérite pas de la garde d'une page.
 */
export const dynamic = 'force-dynamic'

export async function GET() {
  const admin = await adminConnecte()
  if (admin.statut !== 'admin') {
    return Response.json({ ok: false, error: 'Accès réservé.' }, { status: admin.statut === 'deconnecte' ? 401 : 403 })
  }
  const [tableau, paiements] = await Promise.all([lireTableau(), lirePaiements(50)])
  return Response.json(
    { ok: true, data: { tableau, paiements, le: new Date().toISOString() } },
    { headers: { 'cache-control': 'no-store' } },
  )
}
