package com.reviz.app

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.view.ViewGroup
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.addCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.content.FileProvider
import java.io.File

/**
 * Coquille WebView de Reviz.
 *
 * L'application est une web app : cette activité ne fait que l'afficher en
 * plein écran, avec ce qu'un navigateur seul ne sait pas faire — le bouton
 * retour du téléphone, le choix d'un fichier, l'appareil photo, et les liens
 * qui doivent sortir vers WhatsApp.
 *
 * `domStorageEnabled` n'est pas un détail : Supabase garde la session dans
 * `localStorage`. Sans lui, l'étudiant serait déconnecté à chaque ouverture.
 *
 * ## La connexion ne sort pas de l'application
 *
 * Google refuse OAuth dans une WebView embarquée (`disallowed_useragent`) :
 * ce n'est pas contournable, et il ne faut pas essayer. La réponse prévue
 * pour cela est l'onglet personnalisé — le navigateur s'ouvre **dans** la
 * tâche de l'application, aux couleurs de Reviz, sans bascule vers Chrome.
 *
 * Reste que l'onglet ne partage pas les cookies de la WebView, et donc pas le
 * vérificateur PKCE posé au départ. Le retour se fait donc en deux temps :
 *
 *   1. l'onglet finit sur `reviz://auth?code=...`, servi par /auth/rappel ;
 *   2. Android rend la main ici, et c'est la **WebView** qui rejoue
 *      `/auth/rappel?code=...` — elle seule porte le vérificateur.
 *
 * L'étudiant ne quitte jamais Reviz.
 */
class MainActivity : ComponentActivity() {

  private lateinit var vue: WebView

  /** Rappel du choix de fichier en cours, fourni par la page web. */
  private var retourFichier: ValueCallback<Array<Uri>>? = null

  /** Destination de la photo quand l'étudiant choisit l'appareil photo. */
  private var uriPhoto: Uri? = null

  private val choixFichier =
    registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
      val rappel = retourFichier ?: return@registerForActivityResult
      retourFichier = null

      val data = res.data
      val uris: Array<Uri>? =
        when {
          res.resultCode != RESULT_OK -> null
          // Plusieurs pages d'une copie d'un coup.
          data?.clipData != null ->
            Array(data.clipData!!.itemCount) { i -> data.clipData!!.getItemAt(i).uri }
          data?.data != null -> arrayOf(data.data!!)
          // L'appareil photo ne renvoie pas d'URI : c'est celle qu'on lui a
          // donnée qui porte l'image.
          uriPhoto != null -> arrayOf(uriPhoto!!)
          else -> null
        }

      uriPhoto = null
      // Un `null` est obligatoire pour débloquer le champ : sans lui, la page
      // reste à attendre un fichier qui ne viendra jamais.
      rappel.onReceiveValue(uris)
    }

  @SuppressLint("SetJavaScriptEnabled")
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    vue = WebView(this)
    setContentView(
      vue,
      ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
      ),
    )

    vue.settings.apply {
      javaScriptEnabled = true
      // Session Supabase, réglage des animations réduites, brouillons.
      // `databaseEnabled` n'est pas repris : le Web SQL qu'il activait est
      // retiré des WebView modernes, et Supabase n'utilise que localStorage.
      domStorageEnabled = true
      loadWithOverviewMode = true
      useWideViewPort = true
      // La web app est déjà responsive : un zoom manuel ne ferait que casser
      // la mise en page à 375 px.
      builtInZoomControls = false
      displayZoomControls = false
      mediaPlaybackRequiresUserGesture = false
      // Permet à la web app de savoir qu'elle tourne dans la coquille, et de
      // masquer par exemple la page de téléchargement de l'APK.
      userAgentString = "$userAgentString Reviz/$VERSION"
    }

    vue.webViewClient = ClientReviz()
    vue.webChromeClient = ChromeReviz()

    // `onCreate` est rappelé après une rotation : recharger l'accueil ferait
    // perdre la page en cours. `configChanges` dans le manifeste évite le
    // cas courant, ce test couvre le reste.
    if (savedInstanceState != null) vue.restoreState(savedInstanceState)
    else vue.loadUrl(ACCUEIL)

    // Cas du lancement direct par le lien de retour, quand l'application
    // avait été fermée entre-temps.
    traiterRetourAuth(intent)

    onBackPressedDispatcher.addCallback(this) {
      if (vue.canGoBack()) vue.goBack() else finish()
    }
  }

  /**
   * Retour de l'onglet personnalisé.
   *
   * `launchMode="singleTask"` fait arriver le lien ici plutôt que dans une
   * seconde instance : l'onglet se referme, la WebView reprend la main.
   */
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    traiterRetourAuth(intent)
  }

  private fun traiterRetourAuth(intent: Intent?) {
    val donnee = intent?.data ?: return
    if (donnee.scheme != "reviz" || donnee.host != "auth") return

    val erreur = donnee.getQueryParameter("erreur")
    if (erreur != null) {
      val url = Uri.parse("https://$HOTE/connexion").buildUpon()
        .appendQueryParameter("erreur", erreur)
        .build()
      vue.loadUrl(url.toString())
      return
    }

    val code = donnee.getQueryParameter("code")
    if (code == null) {
      vue.loadUrl("https://$HOTE/connexion")
      return
    }

    // L'échange se fait ici, et pas dans l'onglet : le cookie de
    // vérification PKCE n'existe que dans la WebView.
    val url = Uri.parse("https://$HOTE/auth/rappel").buildUpon()
      .appendQueryParameter("code", code)
      .apply {
        donnee.getQueryParameter("suite")?.let { appendQueryParameter("suite", it) }
      }
      .build()

    vue.loadUrl(url.toString())
  }

  override fun onSaveInstanceState(outState: Bundle) {
    super.onSaveInstanceState(outState)
    vue.saveState(outState)
  }

  private inner class ClientReviz : WebViewClient() {

    override fun shouldOverrideUrlLoading(
      view: WebView,
      request: WebResourceRequest,
    ): Boolean {
      val url = request.url

      if (url.scheme == "http" || url.scheme == "https") {
        if (url.host == HOTE) return false

        // Connexion : onglet personnalisé, qui s'ouvre dans l'application.
        // La WebView est refusée par Google, et le navigateur externe ferait
        // sortir l'étudiant de Reviz — précisément ce qu'on veut éviter.
        if (estAuthentification(url)) return ouvrirOnglet(url)

        // Tout le reste sort pour de bon : WhatsApp, Mobile Money, un mail au
        // support. Le garder dans la coquille donnerait une fenêtre sans
        // barre d'adresse et sans issue.
        return ouvrirDehors(url)
      }

      // mailto:, tel:, whatsapp:, intent: — jamais chargeables ici.
      return ouvrirDehors(url)
    }

    override fun onReceivedError(
      view: WebView,
      request: WebResourceRequest,
      error: WebResourceError,
    ) {
      // Seule l'erreur sur la page principale mérite un écran : celle d'une
      // image manquante ne doit pas effacer le contenu.
      if (!request.isForMainFrame) return

      view.loadDataWithBaseURL(null, PAGE_HORS_LIGNE, "text/html", "utf-8", null)
    }
  }

  private inner class ChromeReviz : WebChromeClient() {

    override fun onShowFileChooser(
      view: WebView,
      rappel: ValueCallback<Array<Uri>>,
      params: FileChooserParams,
    ): Boolean {
      // Un choix déjà en cours doit être libéré, sinon la page attend deux
      // réponses et n'en reçoit aucune.
      retourFichier?.onReceiveValue(null)
      retourFichier = rappel

      val depuisFichiers = params.createIntent()
      val veutUneImage =
        params.acceptTypes.any { it.startsWith("image/") || it == "*/*" } ||
          params.acceptTypes.isEmpty()

      val chooser = Intent.createChooser(depuisFichiers, params.title ?: "Choisir")

      // Photographier sa copie ou sa carte étudiante est le cas principal :
      // l'appareil photo doit être proposé au même niveau que la galerie.
      if (veutUneImage) {
        intentAppareilPhoto()?.let { photo ->
          chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(photo))
        }
      }

      return try {
        choixFichier.launch(chooser)
        true
      } catch (_: ActivityNotFoundException) {
        retourFichier = null
        rappel.onReceiveValue(null)
        false
      }
    }
  }

  /**
   * Intent d'appareil photo, ou `null` si le téléphone n'en a pas.
   *
   * La permission `CAMERA` n'est volontairement **pas** déclarée : avec
   * `ACTION_IMAGE_CAPTURE`, c'est l'application appareil photo qui la porte.
   * La déclarer obligerait à demander une autorisation au moment le plus mal
   * choisi — juste avant de prendre la photo.
   */
  private fun intentAppareilPhoto(): Intent? {
    val dossier = File(cacheDir, "photos").apply { mkdirs() }
    val fichier = File(dossier, "capture-${System.currentTimeMillis()}.jpg")

    uriPhoto =
      FileProvider.getUriForFile(this, "$packageName.fileprovider", fichier)

    val intent =
      Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
        putExtra(MediaStore.EXTRA_OUTPUT, uriPhoto)
        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
      }

    return if (intent.resolveActivity(packageManager) != null) intent else null
  }

  /**
   * Cette URL fait-elle partie du parcours de connexion ?
   *
   * Liste explicite : n'importe quel domaine ouvert en onglet plutôt qu'en
   * navigateur donnerait une fenêtre dont l'étudiant ne saurait pas sortir.
   */
  private fun estAuthentification(url: Uri): Boolean {
    val hote = url.host ?: return false
    return hote == "accounts.google.com" ||
      hote.endsWith(".supabase.co") ||
      hote == "accounts.youtube.com"
  }

  private fun ouvrirOnglet(url: Uri): Boolean {
    return try {
      CustomTabsIntent.Builder()
        .setShowTitle(false)
        .setUrlBarHidingEnabled(true)
        .build()
        .launchUrl(this, url)
      true
    } catch (_: ActivityNotFoundException) {
      // Aucun navigateur compatible : le navigateur système reste la seule
      // issue, mieux que rien du tout.
      ouvrirDehors(url)
    }
  }

  private fun ouvrirDehors(url: Uri): Boolean {
    return try {
      startActivity(Intent(Intent.ACTION_VIEW, url))
      true
    } catch (_: ActivityNotFoundException) {
      // Rien pour ouvrir ce lien : mieux vaut ne rien faire que planter.
      true
    }
  }

  private companion object {
    const val VERSION = "1.0.0"
    const val HOTE = "reviz-eight.vercel.app"
    const val ACCUEIL = "https://$HOTE/"

    /**
     * Page d'erreur locale, servie sans réseau.
     *
     * Les couleurs sont celles de docs/DESIGN.md : fond `#fcf9f8`, encre
     * `#1c1b1b`, brun chaud `#4f4632`, jaune `#ffc300`. Écrite en dur parce
     * qu'elle doit s'afficher précisément quand rien ne peut être téléchargé.
     */
    const val PAGE_HORS_LIGNE = """
      <!doctype html><html lang="fr"><head>
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <style>
        html,body{margin:0;height:100%;background:#fcf9f8;
          font-family:system-ui,-apple-system,sans-serif;color:#1c1b1b}
        div{height:100%;display:flex;flex-direction:column;align-items:center;
          justify-content:center;gap:16px;padding:24px;text-align:center}
        h1{font-size:18px;font-weight:800;margin:0}
        p{font-size:15px;font-weight:500;color:#4f4632;margin:0;max-width:280px}
        button{height:56px;padding:0 24px;border:0;border-radius:12px;
          background:#ffc300;color:#311300;font-size:18px;font-weight:800;
          box-shadow:0 4px 0 #d9a400}
      </style></head><body><div>
        <h1>Pas de connexion</h1>
        <p>Reviz a besoin du réseau pour charger tes cours. Vérifie ta
           connexion, puis réessaie.</p>
        <button onclick="location.href='https://reviz-eight.vercel.app/'">
          Réessayer</button>
      </div></body></html>
    """
  }
}
