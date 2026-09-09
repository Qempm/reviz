'use client'

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { useAnimationsReduites } from '@/lib/motion/reduced'
import { Toast, type ToastTone } from './toast'

type Message = { id: number; texte: string; tone: ToastTone; icon?: string }

type Contexte = {
  /** Affiche un toast. Il disparaît seul au bout de `duree`. */
  afficher: (texte: string, options?: { tone?: ToastTone; icon?: string; duree?: number }) => void
}

const ToastContexte = createContext<Contexte | null>(null)

/**
 * File d'affichage des toasts.
 *
 * `Toast` existait déjà mais rien ne l'orchestrait : chaque écran aurait
 * dû gérer sa propre temporisation. Un seul fournisseur, posé à la racine des
 * écrans connectés, suffit.
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [messages, setMessages] = useState<Message[]>([])
  const reduites = useAnimationsReduites()

  const afficher = useCallback<Contexte['afficher']>((texte, options) => {
    const id = Date.now() + Math.random()
    setMessages((m) => [...m, { id, texte, tone: options?.tone ?? 'neutral', icon: options?.icon }])
    setTimeout(() => {
      setMessages((m) => m.filter((x) => x.id !== id))
    }, options?.duree ?? 3500)
  }, [])

  const valeur = useMemo(() => ({ afficher }), [afficher])

  return (
    <ToastContexte.Provider value={valeur}>
      {children}

      <div className="pointer-events-none fixed inset-x-0 bottom-[104px] z-40 mx-auto flex w-full max-w-app flex-col items-center gap-space-8 px-screen-margin-mobile">
        <AnimatePresence>
          {messages.map((m) => (
            <motion.div
              key={m.id}
              initial={reduites ? false : { opacity: 0, y: 16, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 8, scale: 0.96 }}
              transition={{ duration: reduites ? 0 : 0.2 }}
            >
              <Toast message={m.texte} tone={m.tone} icon={m.icon} />
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </ToastContexte.Provider>
  )
}

/**
 * Accès à la file de toasts.
 *
 * Hors fournisseur, renvoie une fonction inerte plutôt que de lever : un
 * composant réutilisable ne doit pas exiger un contexte pour s'afficher.
 */
export function useToast(): Contexte {
  const ctx = useContext(ToastContexte)
  return ctx ?? { afficher: () => {} }
}
