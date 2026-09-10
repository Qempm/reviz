'use client'

import { useEffect, useState } from 'react'

export type VersionStatus = 'ok' | 'update-available' | 'update-required'

export interface VersionInfo {
  version: string
  minimumVersion: string
  latestVersion: string
  buildDate: string
  releaseNotes: string
  updateUrl: string
  critical: boolean
  maintenance: boolean
}

/**
 * Hook pour verifier la version et detecter les mises a jour.
 *
 * Compare la version locale avec le minimumVersion du serveur.
 * Retourne l'etat et les infos de version.
 */
export function useVersionCheck() {
  const [status, setStatus] = useState<VersionStatus>('ok')
  const [versionInfo, setVersionInfo] = useState<VersionInfo | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkVersion = async () => {
      try {
        const res = await fetch('/version.json', {
          cache: 'no-store',
        })

        if (!res.ok) {
          setLoading(false)
          return
        }

        const data = (await res.json()) as VersionInfo
        setVersionInfo(data)

        // Version locale (du fichier version.json)
        const localVersion = data.version

        // Comparer versions : simple comparaison numerique
        const isUpdateRequired = compareVersions(localVersion, data.minimumVersion) < 0
        const isUpdateAvailable = compareVersions(localVersion, data.latestVersion) < 0

        if (isUpdateRequired) {
          setStatus('update-required')
        } else if (isUpdateAvailable) {
          setStatus('update-available')
        } else {
          setStatus('ok')
        }
      } catch (e) {
        console.error('Version check error:', e)
      } finally {
        setLoading(false)
      }
    }

    checkVersion()
  }, [])

  return { status, versionInfo, loading }
}

/**
 * Compare deux versions du type X.Y.Z.
 * Retourne -1 si a < b, 0 si a == b, 1 si a > b.
 */
function compareVersions(a: string, b: string): number {
  const aParts = a.split('.').map(Number)
  const bParts = b.split('.').map(Number)

  for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
    const aPart = aParts[i] ?? 0
    const bPart = bParts[i] ?? 0

    if (aPart < bPart) return -1
    if (aPart > bPart) return 1
  }

  return 0
}
