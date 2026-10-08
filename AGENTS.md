# 📋 Règles de Développement Globales — Noos NAS Ecosystem

> **CONSIGNE IMPÉRATIVE POUR L'AGENT IA :**
> Ce fichier s'applique à l'ensemble du dossier `/home/chomiam/Projets/` et à tous ses sous-projets (`noos-nas-dashboard`, `noos-nas_iso`, `noos_nas_store`, `noos_nas_eggs`).

---

## 🛡️ Règle Première Absolue : Publication exclusive sur la branche `testing`

* **Tout commit, modification de code, tag et push doivent obligatoirement et exclusivement être effectués sur la branche `testing`.**
* **Interdiction formelle absolue de publier, pousser ou fusionner sur la branche `stable` (Stable) sauf si l'utilisateur donne l'instruction explicite et formelle de publier en stable.**
* **Protocole systématique avant toute intervention :**
  1. Vérifier la branche active avec `git branch`.
  2. Basculer immédiatement sur `testing` (`git checkout testing`) si ce n'est pas déjà le cas.
  3. Effectuer les tests locaux ultra-légers (`cargo check`, `node -c`).
  4. Pousser exclusivement sur `origin testing` :
     ```bash
     git push origin testing --tags
     ```

---

## 🚫 Règle n°2 : Pas de build lourd sur la machine locale

* **Ne jamais lancer de compilation complète ou lourde (`nix build`, `cargo build --release`, recompilation d'ISO) sur la machine locale.**
* La machine locale n'exécute que des vérifications de syntaxe (`cargo check`, `cargo clippy`, `node -c`).
* La compilation binaire est obligatoirement déléguée aux serveurs distants via **GitHub Actions** (`.github/workflows/build.yml`) alimentant le cache Cachix `steveos.cachix.org`.

---

## ✍️ Règle n°3 : Commits avec explications détaillées en français & Bug Tracking

* Chaque commit doit contenir une explication claire et détaillée en français.
* Si le commit résout un bogue ou une anomalie, mentionner l'identifiant GitHub Issue `[BUG-YYYYMMDD-XX]` et le numéro de ticket (`Closes #XX`).
