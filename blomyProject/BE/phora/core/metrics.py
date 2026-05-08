from prometheus_client import Counter, Gauge, generate_latest
from starlette.responses import Response


PREDICTION_COUNTER = Counter(
    "phora_predictions_total",
    "Total prediction runs attempted",
    ["source", "status"],
)
ML_HEALTH_GAUGE = Gauge("phora_ml_health", "ML service health flag")
QUEUE_LAG_GAUGE = Gauge("phora_queue_lag", "Queue lag placeholder", ["queue"])


def metrics_response() -> Response:
    return Response(generate_latest(), media_type="text/plain; version=0.0.4")

