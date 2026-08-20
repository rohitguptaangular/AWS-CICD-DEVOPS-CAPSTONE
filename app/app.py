from flask import Flask
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
metrics = PrometheusMetrics(app)
metrics.info("herovire_app_info", "Application info", version="1.0.0")


@app.route("/")
def home():
    return "Hello from the Herovire DevOps capstone pipeline! 🚀 - now shipped via GitOps (v2)\n"


@app.route("/health")
def health():
    return {"status": "healthy"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
