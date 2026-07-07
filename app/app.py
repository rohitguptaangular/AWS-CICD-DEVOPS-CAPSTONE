from flask import Flask

# Webhook test: this push should auto-trigger a Jenkins build (Sprint 1, task 1.7).
app = Flask(__name__)


@app.route("/")
def home():
    return "Hello from the Herovire DevOps capstone pipeline! 🚀\n"


# Health-check endpoint.
# Kubernetes (Sprint 4) uses this for liveness/readiness probes,
# and Prometheus (Sprint 5) can scrape it to confirm the app is up.
@app.route("/health")
def health():
    return {"status": "healthy"}, 200


if __name__ == "__main__":
    # Only used when running locally with `python app.py`.
    # In the container we use gunicorn instead (see Dockerfile).
    app.run(host="0.0.0.0", port=5000)
