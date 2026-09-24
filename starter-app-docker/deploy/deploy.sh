#!/usr/bin/env bash

set -e

ACTIVE=$(tr -d '\r\n' < deploy/active_color)
EXPECTED_SHA="${EXPECTED_SHA:-${COMMIT_SHA:-unknown}}"

if [ "$ACTIVE" = "blue" ]; then
    IDLE="green"
    PORT="5002"
else
    IDLE="blue"
    PORT="5001"
fi

echo "Couleur active : $ACTIVE"
echo "Nouvelle couleur : $IDLE"
echo "SHA attendu : $EXPECTED_SHA"

echo "Demarrage de l'infrastructure de base"
docker compose up -d redis nginx

docker compose --profile "$IDLE" up -d --build "app-$IDLE"

READY=0

for _ in $(seq 1 15); do
    if curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
        READY=1
        break
    fi

    sleep 2
done

if [ "$READY" -ne 1 ]; then
    echo "ECHEC : app-$IDLE ne repond pas sur /health"
    echo "ROLLBACK : arret de app-$IDLE, $ACTIVE reste actif"

    docker compose --profile "$IDLE" stop "app-$IDLE"
    exit 1
fi

echo "Healthcheck OK"

DEPLOY_COLOR=$(curl -sf "http://localhost:$PORT/status" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['deploy_color'])")

DEPLOYED_SHA=$(curl -sf "http://localhost:$PORT/status" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['commit_sha'])")

if [ "$DEPLOY_COLOR" != "$IDLE" ]; then
    echo "ECHEC : mauvaise couleur detectee"
    echo "ROLLBACK : arret de app-$IDLE, $ACTIVE reste actif"

    docker compose --profile "$IDLE" stop "app-$IDLE"
    exit 1
fi

if [ "$DEPLOYED_SHA" != "$EXPECTED_SHA" ]; then
    echo "ECHEC : SHA deploye incorrect"
    echo "SHA attendu : $EXPECTED_SHA"
    echo "SHA deploye : $DEPLOYED_SHA"
    echo "ROLLBACK : arret de app-$IDLE, $ACTIVE reste actif"

    docker compose --profile "$IDLE" stop "app-$IDLE"
    exit 1
fi

echo "Smoke test OK"
echo "SHA verifie : $DEPLOYED_SHA"

sed -i "s/app-$ACTIVE:5000/app-$IDLE:5000/" deploy/nginx.conf

docker exec starter-app-docker-nginx-1 nginx -s reload

echo "$IDLE" > deploy/active_color

docker compose --profile "$ACTIVE" stop "app-$ACTIVE" || true

echo "Deploiement reussi : $IDLE est maintenant actif"

