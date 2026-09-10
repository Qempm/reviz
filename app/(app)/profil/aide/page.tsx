import Link from 'next/link'
import { Card, Icon } from '@/components/ui'

/**
 * Ecran - Centre d'aide.
 *
 * FAQ et contacts de support.
 */

const FAQS = [
  {
    question: 'Comment ajouter un cours ?',
    reponse: 'Va sur l\'accueil, clique sur "Ajouter un cours". Upload un PDF ou des photos. Reviz genere automatiquement des QCM et des fiches.',
  },
  {
    question: 'Comment fonctionne le parrainage ?',
    reponse: 'Partage ton code parrain dans l\'onglet Gains. Tu touches 25% de chaque paiement de tes filleuls pendant 12 mois.',
  },
  {
    question: 'Quel est le montant minimum pour un retrait ?',
    reponse: '3 000 FCFA. Tu peux demander un retrait depuis l\'onglet Gains une fois ce seuil atteint.',
  },
  {
    question: 'Mes donnees sont-elles en securite ?',
    reponse: 'Oui. Tes donnees sont chiffrees et stockees sur des serveurs securises. Aucun partage avec des tiers sans ton consentement.',
  },
  {
    question: 'Peux-tu modifier mes informations ?',
    reponse: 'Email et universite ne peuvent pas etre changes. Tu peux changer ton numero de telephone, ta filiere et ton avatar.',
  },
  {
    question: 'Comment sont calculees les notes ?',
    reponse: 'Nos IA (DeepSeek, Qwen, GLM) analysent tes copies et les notent sur 20. Les baremes sont bases sur le sujet fourni.',
  },
]

export default function Aide() {
  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <Link href="/profil" className="mb-space-8">
          <Icon name="arrow_back" size={24} className="text-reviz-ink" />
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">Centre d\'aide</h1>
        <p className="text-body-md text-reviz-muted">Questions frequemment posees.</p>
      </header>

      {/* FAQ */}
      <div className="space-y-space-12">
        {FAQS.map((faq, i) => (
          <Card key={i}>
            <details className="cursor-pointer">
              <summary className="flex items-center justify-between text-label-lg text-reviz-ink font-600 hover:text-primary transition-colors">
                <span>{faq.question}</span>
                <Icon name="expand_more" size={20} className="text-reviz-muted" />
              </summary>
              <p className="text-body-md text-reviz-muted mt-space-12">
                {faq.reponse}
              </p>
            </details>
          </Card>
        ))}
      </div>

      {/* Contact */}
      <Card>
        <div className="flex flex-col gap-space-12">
          <span className="text-label-lg text-reviz-ink font-600">Tu ne trouves pas la reponse ?</span>
          <p className="text-body-md text-reviz-muted">
            Contacte-nous sur WhatsApp pour une aide personalise.
          </p>
          <a
            href="https://wa.me/22961234567?text=Bonjour%20Reviz,%20j%27ai%20une%20question"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center justify-center gap-space-8 rounded-xl bg-reviz-yellow px-space-16 py-space-12 text-label-lg text-reviz-on-yellow font-600 hover:brightness-95 transition-all"
          >
            <Icon name="chat" size={20} />
            Envoyer un message
          </a>
        </div>
      </Card>

      {/* Infos legales */}
      <Card size="sm">
        <div className="flex flex-col gap-space-8 text-label-sm text-reviz-muted">
          <a href="/conditions" className="hover:text-primary">Conditions d\'utilisation</a>
          <a href="/confidentialite" className="hover:text-primary">Politique de confidentialite</a>
          <p>© 2026 Reviz. Tous droits reserves.</p>
        </div>
      </Card>
    </div>
  )
}
