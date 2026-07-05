# ---- Base image ----
# "slim" is a stripped-down Debian + Python. Smaller image =
# faster ECR pushes/pulls and lower storage cost (Sprint cost-optimization goal).
FROM python:3.12-slim

# Send Python logs straight to the terminal (unbuffered) so they
# show up immediately in Jenkins and in `kubectl logs`.
ENV PYTHONUNBUFFERED=1

# All work happens inside /app inside the container.
WORKDIR /app

# Copy the dependency list FIRST, install, THEN copy the code.
# Docker caches each step as a layer. Because requirements rarely change,
# the (slow) pip-install layer is reused on future builds — only re-running
# when requirements.txt actually changes. This makes rebuilds much faster.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the application code.
COPY app.py .

# Run as a non-root user (security best practice — containers should not
# run as root unless they truly need to).
RUN useradd --create-home appuser
USER appuser

# Documents which port the app listens on (informational).
EXPOSE 5000

# Start the app with gunicorn, a production-grade WSGI server.
# (Flask's built-in server is for development only.)
# "app:app" = in the file app.py, use the object named `app`.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
