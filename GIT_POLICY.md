# 🛡️ Politique Git & Stratégie de Branches Obligatoire

> **CONSIGNE IMPÉRATIVE POUR L'AGENT IA ET TOUT DÉVELOPPEUR :**
> Toute opération de commit, de modification de code, de tag ou de push doit respecter scrupuleusement les règles suivantes.

---

## 🚫 Règle Absolue : Travail EXCLUSIF sur la branche `testing`

* **Interdiction formelle de commiter, modifier ou pousser directement sur la branche `stable`.**
* **Toute modification et tout commit doivent être effectués UNIQUEMENT sur la branche `testing`.**
* **Seule exception :** Si et seulement si l'utilisateur donne l'instruction formelle et explicite de déployer ou publier en `stable`.

---

## 📋 Cycle de Travail Standard

1. **Vérification de la branche active** avant toute modification :
   ```bash
   git branch
   git checkout testing
   ```
2. **Développement & Vérifications ultra-légères** (sans compilation lourde locale) :
   ```bash
   cargo check
   node -c frontend/js/app.js
   ```
3. **Commit & Push sur `testing`** :
   ```bash
   git add <fichiers_modifiés>
   git commit -m "type(scope): description détaillée en français"
   git push origin testing --tags
   ```
4. **Déploiement en `stable`** : Uniquement sur demande explicite de l'utilisateur (ex: *"Déploie en stable"* ou *"Passe la version en stable"*).
