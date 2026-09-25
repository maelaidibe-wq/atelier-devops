import os
import time
import redis

from flask import Flask, jsonify, request, Response
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST
)

app = Flask(__name__)

ALERT_THRESHOLD = 25

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Nombre total de requetes HTTP recues",
    ["method", "endpoint", "status"]
)

REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "Duree de traitement d'une requete HTTP, en secondes",
    ["method", "endpoint"]
)


def get_redis_client():
    return redis.Redis(
        host=os.getenv("REDIS_HOST", "redis"),
        port=6379,
        decode_responses=True
    )


def alert_threshold():
    """Seuil d'alerte au-dessus duquel une notification est declenchee."""
    return ALERT_THRESHOLD


def sanitize_input(value):
    """Echappe les caracteres dangereux d'une entree utilisateur."""
    return value.replace("<", "&lt;").replace(">", "&gt;")


@app.before_request
def start_request_timer():
    request._metrics_start = time.perf_counter()


@app.after_request
def record_request_metrics(response):
    if request.path == "/metrics":
        return response

    endpoint = request.url_rule.rule if request.url_rule else "unmatched"
    duration = time.perf_counter() - request._metrics_start

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status=response.status_code
    ).inc()

    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=endpoint
    ).observe(duration)

    return response


@app.route("/health")
def health():
    try:
        redis_client = get_redis_client()
        redis_client.ping()
        return jsonify(status="ok", redis="ok"), 200
    except redis.RedisError:
        return jsonify(status="error", redis="unavailable"), 503


@app.route("/status")
def status():
    return jsonify(
        service="projet-devops-groupe-demo",
        version="1.0",
        deploy_color=os.getenv("DEPLOY_COLOR", "unknown"),
        commit_sha=os.getenv("COMMIT_SHA", "unknown")
    ), 200


@app.route("/visits")
def visits():
    redis_client = get_redis_client()
    count = redis_client.incr("visits")
    return jsonify(visits=count), 200


@app.route("/simulate-error")
def simulate_error():
    return jsonify(error="simulated error"), 500


@app.route("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
