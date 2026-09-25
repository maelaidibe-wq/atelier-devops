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

## Séance 3 - Conteneurisation Docker

L'application Flask a été conteneurisée avec Docker puis optimisée avec un build multi-stage.

### Construction de l'image

Depuis le dossier `starter-app-docker` :

```bash
docker build -t starter-app-multistage:1.0 .

## Séance 5 - Observabilité avec Prometheus et Grafana

L'application Flask a été instrumentée afin de fournir des métriques applicatives exploitables par Prometheus et Grafana.

La stack d'observabilité comprend :

- l'application Flask ;
- Redis ;
- Nginx ;
- Prometheus ;
- Grafana.

### Lancer la stack

Depuis le dossier `starter-app-docker` :

```bash
docker compose --profile blue up -d --build
```

Pour vérifier l'état des conteneurs :

```bash
docker compose --profile blue ps
```

### Accès aux services

- Application Flask Blue : `http://localhost:5001`
- Nginx : `http://localhost:8080`
- Prometheus : `http://localhost:9090`
- Grafana : `http://localhost:3000`

### Métriques applicatives

L'application expose ses métriques Prometheus sur l'endpoint :

```text
/metrics
```

Deux métriques applicatives principales ont été ajoutées :

- `http_requests_total` : compteur du nombre total de requêtes HTTP, avec les labels `method`, `endpoint` et `status` ;
- `http_request_duration_seconds` : histogramme permettant de mesurer la durée des requêtes et de calculer notamment une latence p95.

L'endpoint `/metrics` est exclu du compteur afin que les scrapes Prometheus ne faussent pas les statistiques.

Un endpoint `/simulate-error` a également été ajouté afin de générer volontairement des réponses HTTP 500 pour tester l'alerting.

### Prometheus

Prometheus collecte les métriques de l'application toutes les 5 secondes.

Dans le réseau Docker Compose, Prometheus accède à l'application avec la cible :

```text
app-blue:5000
```

L'état des cibles peut être consulté sur :

```text
http://localhost:9090/targets
```

Les cibles `flask-app` et `prometheus` doivent apparaître à l'état `UP`.

### Requêtes PromQL utilisées

Débit de requêtes par endpoint :

```promql
sum by (endpoint) (
  rate(http_requests_total[1m])
)
```

Taux d'erreur HTTP global :

```promql
sum(rate(http_requests_total{status=~"5.."}[1m]))
/
sum(rate(http_requests_total[1m]))
```

Latence p95 par endpoint :

```promql
histogram_quantile(
  0.95,
  sum by (le, endpoint) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

### Grafana

La datasource Prometheus est provisionnée automatiquement au démarrage de Grafana à partir du fichier :

```text
observability/grafana/provisioning/datasources/datasource.yml
```

L'URL utilisée par Grafana pour joindre Prometheus est :

```text
http://prometheus:9090
```

Le dashboard est également provisionné automatiquement à partir d'un fichier JSON.

Il est disponible dans Grafana dans :

```text
Dashboards > DevOps > Observabilite - Projet DevOps
```

Le dashboard contient trois panneaux :

- requêtes par seconde par endpoint ;
- taux d'erreur global ;
- latence p95 par endpoint.

### Alerting Prometheus

Une règle d'alerte Prometheus nommée `TauxErreurEleve` est configurée.

Elle se déclenche lorsque le taux de réponses HTTP 5xx dépasse 5 % pendant au moins 30 secondes.

Expression PromQL :

```promql
sum(rate(http_requests_total{status=~"5.."}[1m]))
/
sum(rate(http_requests_total[1m])) > 0.05
```

Durée avant déclenchement :

```text
30 secondes
```

Les alertes peuvent être consultées sur :

```text
http://localhost:9090/alerts
```

L'endpoint `/simulate-error` permet de générer des erreurs HTTP 500 afin de tester la règle.

Pendant le TP, les différents états de l'alerte ont été observés :

```text
inactive -> pending -> firing
```

Le déclenchement réel de l'état `firing` a été vérifié.

### Organisation des fichiers d'observabilité

```text
observability/
├── prometheus.yml
├── alert_rules.yml
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasource.yml
        └── dashboards/
            ├── dashboards.yml
            └── json/
                └── dashboard.json
```


