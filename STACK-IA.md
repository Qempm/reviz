# STACK IA — SaaS de révision étudiant

Document de référence pour les appels API des modèles chinois retenus.
Vérifié sur les documentations officielles le **8 septembre 2026**.
Les prix bougent tous les trimestres : re-vérifier avant chaque montée en charge.

---

## 0. Principe de la stack

Les trois fournisseurs parlent le **format OpenAI Chat Completions**. Un seul
nœud HTTP Request dans n8n suffit : on change `base_url`, la clé et le nom du
modèle, et la structure du corps JSON reste identique. C'est ce qui rend la
bascule d'un fournisseur à l'autre triviale.

| Rôle dans le SaaS | Fournisseur principal | Secours |
|---|---|---|
| Génération QCM / fiches / questions probables | DeepSeek `deepseek-v4-flash` | Qwen `qwen3.8-flash` |
| Lecture photo (copie, carte étudiante) | DeepSeek `deepseek-v4-flash-vision-exp` | GLM `glm-5.3-flash` (accepte les images) |
| Correction notée difficile (maths, droit) | DeepSeek `deepseek-v4-pro` | GLM `glm-5.3` |
| Tâches sans enjeu (classer un fichier par matière) | Ollama local | — |

Règles d'or :

1. **Une clé par fournisseur, à ton nom**, stockée dans les *Credentials* n8n
   (type « Header Auth » ou « OpenAI »), jamais en dur dans un nœud, et jamais
   la clé d'un client.
2. **Cache par hash de fichier** : avant tout appel, SHA-256 du document. Si le
   hash existe déjà dans Supabase, on réutilise les questions générées.
3. **Heures creuses DeepSeek** : les traitements lourds (ingestion d'un cours)
   passent par une file et tournent hors des créneaux 02h–05h et 07h–11h
   (heure de Cotonou, lundi–vendredi).
4. **JSON strict** en sortie pour tout ce qui est stocké en base.
5. **Plafonds** : 150 pages par cours, 200 questions par cours, quota
   journalier par étudiant même en pass illimité.

---

## 1. DeepSeek (choix n°1)

### 1.1 Paramètres

| Paramètre | Valeur |
|---|---|
| base_url (format OpenAI) | `https://api.deepseek.com` |
| base_url (format Anthropic) | `https://api.deepseek.com/anthropic` |
| Endpoint chat | `POST https://api.deepseek.com/chat/completions` |
| Clé | https://platform.deepseek.com/api_keys (commence par `sk-`) |
| Modèles | `deepseek-v4-flash` · `deepseek-v4-pro` · `deepseek-v4-flash-vision-exp` |
| Contexte | 1M tokens, sortie max 384K |
| Anciens alias | `deepseek-chat` et `deepseek-reasoner` sont **retirés** depuis le 24/07/2026 |

### 1.2 Prix (par million de tokens, USD)

Tarification **heures pleines / heures creuses** depuis le 16/08/2026.
Heures pleines : 01:00–04:00 et 06:00–10:00 UTC, lundi–vendredi
(= **02h–05h et 07h–11h à Cotonou**). Le reste du temps, moitié prix.

| Modèle | Entrée cache miss | Entrée cache hit | Sortie |
|---|---|---|---|
| `deepseek-v4-flash` (creuses) | 0,22 | 0,007 | 0,66 |
| `deepseek-v4-flash` (pleines) | 0,44 | 0,014 | 1,32 |
| `deepseek-v4-flash-vision-exp` | identique à Flash | | |
| `deepseek-v4-pro` (creuses) | 0,66 | 0,022 | 1,98 |
| `deepseek-v4-pro` (pleines) | 1,32 | 0,044 | 3,96 |

Nouveau compte : 5 millions de tokens offerts, sans carte bancaire.
DeepSeek a annoncé une hausse future sans date : garder Qwen prêt en secours.

### 1.3 Limites de concurrence

| | v4-pro | v4-flash | v4-flash-vision-exp |
|---|---|---|---|
| Requêtes simultanées par compte | 500 | 2500 | 2500 |

Au-delà : HTTP 429. Extension gratuite sur demande.
Le cache de contexte est automatique : tout préfixe identique (system prompt +
cours) est facturé au tarif cache hit à partir du deuxième appel.

### 1.4 Appel de base (génération de QCM)

```bash
curl https://api.deepseek.com/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -d '{
    "model": "deepseek-v4-flash",
    "messages": [
      {"role": "system", "content": "Tu es un enseignant. À partir du cours fourni, génère des QCM en JSON. Format attendu : {\"questions\":[{\"question\":\"...\",\"options\":[\"A\",\"B\",\"C\",\"D\"],\"reponse\":\"B\",\"explication\":\"...\",\"chapitre\":\"...\"}]}"},
      {"role": "user", "content": "COURS :\n<texte du chapitre>\n\nGénère 20 questions de niveau examen."}
    ],
    "response_format": {"type": "json_object"},
    "max_tokens": 8000,
    "temperature": 0.7,
    "stream": false,
    "user_id": "etudiant_123"
  }'
```

Notes officielles sur le mode JSON :
- `response_format: {"type": "json_object"}` + le mot **json** dans le prompt
  + un exemple de structure, sinon le modèle peut ignorer le format.
- Régler `max_tokens` assez haut, sinon le JSON est tronqué.
- Le modèle renvoie parfois un contenu vide en mode JSON : prévoir un retry.

`user_id` (chaîne `[a-zA-Z0-9\-_]+`, max 512 caractères, jamais de donnée
personnelle) isole le cache et la modération par étudiant. Avec le SDK OpenAI,
le passer dans `extra_body`.

### 1.5 Mode réflexion (pour `deepseek-v4-pro` sur les corrections)

```json
{
  "model": "deepseek-v4-pro",
  "messages": [...],
  "thinking": {"type": "enabled"},
  "reasoning_effort": "high"
}
```

Ne pas activer pour la génération de QCM : ça multiplie les tokens de sortie
sans gain.

### 1.6 Vision (photo de copie ou de carte étudiante)

Formats : JPEG, PNG, GIF, WebP. Image uniquement dans un message `user`.
Chaque image est redimensionnée vers ~800×800 → **384 tokens maximum par
image**, donc une photo de copie coûte moins de 0,001 $.

```bash
curl https://api.deepseek.com/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -d '{
    "model": "deepseek-v4-flash-vision-exp",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "Extrais en json : nom, université, filière, année académique, date de validité. Si un champ est illisible, mets null."},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<BASE64>", "detail": "original"}}
      ]
    }],
    "response_format": {"type": "json_object"}
  }'
```

- Une URL publique `https://` fonctionne aussi (max 32 MiB, téléchargement
  < 60 s) : pratique avec une URL signée Supabase Storage.
- `detail: "low"` réduit à 512×512 : suffisant pour classer, pas pour lire une
  écriture manuscrite.
- Corps de requête max 48 MiB ; 600 images par requête.

### 1.7 Codes d'erreur à gérer

| Code | Cause | Action n8n |
|---|---|---|
| 401 | clé invalide | alerte |
| 402 | solde épuisé | bascule Qwen + alerte WhatsApp |
| 422 | paramètres invalides | log |
| 429 | concurrence dépassée | attente 2 s puis retry (3 fois), sinon Qwen |
| 500 / 503 | serveur surchargé | bascule Qwen |

---

## 2. Qwen — Alibaba Cloud Model Studio (secours texte)

### 2.1 Paramètres

| Paramètre | Valeur |
|---|---|
| base_url international (Singapour) | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` |
| Endpoint chat | `POST .../compatible-mode/v1/chat/completions` |
| Clé | console Model Studio, variable `DASHSCOPE_API_KEY` |
| Modèle texte pas cher | `qwen3.8-flash` (1M contexte, prix plat) |
| Modèle texte le moins cher | `qwen3.7-flash` (prix par paliers de contexte) |
| Modèles vision | `qwen3-vl-flash`, `qwen-vl-ocr` |

Ne pas utiliser `dashscope.aliyuncs.com` (sans `-intl`) : c'est la région
Pékin, clés et facturation séparées.

### 2.2 Prix (par million de tokens, USD)

| Modèle | Entrée | Sortie | Remarque |
|---|---|---|---|
| `qwen3.7-flash` | 0,03 | 0,13 | sous 32K tokens ; monte à 0,20 / 0,80 au-delà de 256K |
| `qwen3.8-flash` | 0,14 | 0,42 | prix plat sur 1M, sorti le 26/08/2026 |
| `qwen3.8-max` | 2,00 | 6,00 | hors budget |

Pour un cours découpé en chapitres (< 32K tokens chacun), `qwen3.7-flash`
est le modèle le moins cher du marché. Pour envoyer un cours entier d'un
coup, `qwen3.8-flash`.

### 2.3 Appel

```bash
curl https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -d '{
    "model": "qwen3.8-flash",
    "messages": [
      {"role": "system", "content": "<même system prompt que DeepSeek>"},
      {"role": "user", "content": "<même contenu>"}
    ],
    "response_format": {"type": "json_object"},
    "max_tokens": 8000,
    "temperature": 0.7
  }'
```

Même corps que DeepSeek : le seul changement est l'URL, la clé et `model`.
Retirer `user_id` et `thinking` (paramètres spécifiques DeepSeek) avant
d'envoyer à Qwen.

### 2.4 Vision Qwen (si DeepSeek Vision tombe)

```json
{
  "model": "qwen3-vl-flash",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "text", "text": "..."},
      {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<BASE64>"}}
    ]
  }]
}
```

---

## 3. GLM — Z.ai (secours vision + correction)

### 3.1 Paramètres

| Paramètre | Valeur |
|---|---|
| base_url | `https://api.z.ai/api/paas/v4/` |
| Endpoint chat | `POST https://api.z.ai/api/paas/v4/chat/completions` |
| Clé | console Z.ai, variable `ZAI_API_KEY` |
| Modèle pas cher | `glm-5.3-flash` (1M contexte, **vision native**, raisonnement) |
| Modèle fort | `glm-5.3` (1,3M contexte) |

Le Coding Plan Z.ai utilise une autre URL de base : ne pas la confondre avec
l'API pay-per-token ci-dessus.

### 3.2 Prix (par million de tokens, USD)

| Modèle | Entrée | Sortie |
|---|---|---|
| `glm-5.3-flash` | 0,15 | 0,50 |
| `glm-5.3` | 1,40 | 4,40 |

### 3.3 Appel (texte ou image, même modèle)

```bash
curl https://api.z.ai/api/paas/v4/chat/completions \
  -H "Content-Type: application/json" \
  -H "Accept-Language: en-US,en" \
  -H "Authorization: Bearer $ZAI_API_KEY" \
  -d '{
    "model": "glm-5.3-flash",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "Corrige cette copie avec le barème fourni. Réponds en json."},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<BASE64>"}}
      ]
    }],
    "reasoning_effort": "low",
    "max_tokens": 4000
  }'
```

`reasoning_effort` accepte `low`, `high`, `max` ; le défaut est `high`, donc
le forcer à `low` pour tout ce qui n'est pas une correction.

---

## 4. Intégration n8n

### 4.1 Credentials à créer (une fois)

| Nom | Type | Header |
|---|---|---|
| `deepseek-api` | Header Auth | `Authorization: Bearer sk-...` |
| `qwen-api` | Header Auth | `Authorization: Bearer sk-...` |
| `zai-api` | Header Auth | `Authorization: Bearer ...` |

Alternative : le nœud **OpenAI Chat Model** de n8n accepte une *Base URL*
personnalisée dans ses credentials. Ça marche pour DeepSeek et Qwen (format
OpenAI pur) mais le nœud HTTP Request reste préférable pour maîtriser
`response_format`, `user_id` et les retries.

### 4.2 Nœud HTTP Request type

- Method : `POST`
- URL : expression `{{ $json.base_url }}/chat/completions`
- Authentication : Generic → Header Auth → credential du fournisseur
- Body : JSON, expression `{{ JSON.stringify($json.payload) }}`
- Options → Timeout : 120 000 ms (les cours longs prennent du temps)
- Options → Retry On Fail : 3 tentatives, 2 000 ms
- Settings → On Error : *Continue (using error output)* → branche secours

### 4.3 Code node « sélection du fournisseur »

Mode *Run Once for All Items*. Reçoit `{ task, tentative }`, renvoie l'URL,
le modèle et le nom du credential à utiliser.

```javascript
const items = $input.all();

const ROUTES = {
  qcm: [
    { provider: 'deepseek', base_url: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash' },
    { provider: 'qwen', base_url: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      model: 'qwen3.8-flash' },
    { provider: 'zai', base_url: 'https://api.z.ai/api/paas/v4',
      model: 'glm-5.3-flash' }
  ],
  vision: [
    { provider: 'deepseek', base_url: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash-vision-exp' },
    { provider: 'zai', base_url: 'https://api.z.ai/api/paas/v4',
      model: 'glm-5.3-flash' },
    { provider: 'qwen', base_url: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      model: 'qwen3-vl-flash' }
  ],
  correction: [
    { provider: 'deepseek', base_url: 'https://api.deepseek.com',
      model: 'deepseek-v4-pro' },
    { provider: 'zai', base_url: 'https://api.z.ai/api/paas/v4',
      model: 'glm-5.3' }
  ]
};

// Heures pleines DeepSeek : 01–04h et 06–10h UTC, lundi–vendredi
function deepseekHeurePleine() {
  const now = DateTime.utc();
  const h = now.hour;
  const jourOuvre = now.weekday <= 5;
  return jourOuvre && ((h >= 1 && h < 4) || (h >= 6 && h < 10));
}

return items.map(item => {
  const task = item.json.task || 'qcm';
  const tentative = item.json.tentative || 0;
  const routes = ROUTES[task];
  const route = routes[Math.min(tentative, routes.length - 1)];

  return {
    json: {
      ...item.json,
      ...route,
      heure_pleine: route.provider === 'deepseek' ? deepseekHeurePleine() : false,
      tentative
    }
  };
});
```

Sur la sortie d'erreur du HTTP Request, un Set node fait `tentative + 1` et
reboucle sur ce Code node. Après 3 tentatives, alerte WhatsApp et l'étudiant
reçoit « traitement en cours, tu seras notifié ».

### 4.4 Code node « normalisation du payload »

DeepSeek accepte `user_id` et `thinking`, les autres non. Ce nœud nettoie le
corps avant l'envoi.

```javascript
const items = $input.all();

return items.map(item => {
  const { provider, model, system_prompt, user_content, task } = item.json;

  const payload = {
    model,
    messages: [
      { role: 'system', content: system_prompt },
      { role: 'user', content: user_content }
    ],
    response_format: { type: 'json_object' },
    max_tokens: task === 'correction' ? 4000 : 8000,
    temperature: task === 'correction' ? 0.2 : 0.7,
    stream: false
  };

  if (provider === 'deepseek') {
    payload.user_id = item.json.etudiant_id;
    if (task === 'correction') {
      payload.thinking = { type: 'enabled' };
      payload.reasoning_effort = 'high';
    }
  }
  if (provider === 'zai') {
    payload.reasoning_effort = task === 'correction' ? 'high' : 'low';
  }

  return { json: { ...item.json, payload } };
});
```

### 4.5 Lecture de la réponse

Les trois fournisseurs renvoient le texte dans
`choices[0].message.content` et la consommation dans `usage`.

```javascript
const items = $input.all();

return items.map(item => {
  const r = item.json;
  const contenu = r.choices?.[0]?.message?.content || '';
  let data;
  try {
    data = JSON.parse(contenu.replace(/```json|```/g, '').trim());
  } catch (e) {
    data = null; // → renvoyer vers la branche retry
  }
  return {
    json: {
      data,
      tokens_entree: r.usage?.prompt_tokens || 0,
      tokens_sortie: r.usage?.completion_tokens || 0,
      cache_hit: r.usage?.prompt_cache_hit_tokens || 0,
      modele: r.model
    }
  };
});
```

Stocker `tokens_entree`, `tokens_sortie` et `modele` dans une table
`ia_usage` Supabase à chaque appel : c'est ce qui te permettra de vérifier
que le coût IA reste sous 2 % du chiffre d'affaires.

---

## 5. Plan de migration vers ton VPS

1. **Maintenant** : workflows sur l'instance n8n disponible, avec tes clés
   API et tes credentials. Exporter les workflows en JSON dans un dépôt Git
   dès le premier jour.
2. **Bascule** : sur ton VPS, `docker compose` avec n8n + Postgres, importer
   les JSON, recréer les 3 credentials, rebrancher les webhooks Supabase et
   Mobile Money vers le nouveau domaine. Rien à changer dans les workflows.
3. **Ollama** : installé en local sur ton PC pour prototyper ; sur le VPS
   seulement si tu as de la RAM libre, et uniquement pour les tâches sans
   enjeu.

---

## 6. Sources officielles

- DeepSeek — première requête : https://api-docs.deepseek.com/
- DeepSeek — prix : https://api-docs.deepseek.com/quick_start/pricing
- DeepSeek — vision : https://api-docs.deepseek.com/guides/vision
- DeepSeek — JSON : https://api-docs.deepseek.com/guides/json_mode
- DeepSeek — concurrence et user_id : https://api-docs.deepseek.com/quick_start/rate_limit
- DeepSeek — cache : https://api-docs.deepseek.com/guides/kv_cache
- Qwen — compatibilité OpenAI (vision) : https://www.alibabacloud.com/help/en/model-studio/qwen-vl-compatible-with-openai
- Z.ai — démarrage rapide : https://docs.z.ai/guides/overview/quick-start
