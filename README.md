# Atelier DevOps - Git avancé

Projet réalisé dans le cadre de la séance 1 DevOps.

## Stratégie de branches

Nous utilisons la stratégie **Trunk-Based Development**.

- `main` est la branche principale.
- Les développements sont réalisés sur des branches courtes.
- Convention de nommage : `feature/nom`, `fix/nom`, `chore/nom`.
- Aucun développement important ne doit être réalisé directement sur `main`.
- Les modifications sont intégrées à `main` via une Pull Request après revue.
- Une fois la Pull Request fusionnée, la branche de travail est supprimée (pas fait pour preuves)


## Pipeline CI - GitHub Actions

[![CI](https://github.com/maelaidibe-wq/atelier-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/maelaidibe-wq/atelier-devops/actions/workflows/ci.yml)

Le projet utilise GitHub Actions pour exécuter automatiquement les contrôles de qualité et les tests.

### Déclenchement

Le pipeline CI se déclenche :
- lors d'une Pull Request ;
- lors d'un push sur la branche `main`.

### Jobs

Le pipeline contient deux jobs :
- `lint` : vérifie la qualité du code avec Flake8 ;
- `test` : exécute les tests avec Pytest après la réussite du job `lint`.

### Matrice Python

Les tests sont exécutés sur trois versions de Python :
- Python 3.10
- Python 3.11
- Python 3.12

### Cache et couverture

Les dépendances pip sont mises en cache afin d'accélérer les exécutions du pipeline.

Un rapport de couverture HTML est généré avec pytest-cov. Les rapports sont disponibles dans les artefacts de l'exécution GitHub Actions sous les noms :
- `coverage-html-3.10`
- `coverage-html-3.11`
- `coverage-html-3.12`
