from fastapi import FastAPI
from datetime import datetime, timezone
import os

app = FastAPI(title="InfraForge Demo API", version="1.0.0")


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/")
def root():
    return {
        "service": "fastapi-demo",
        "version": "1.0.0",
        "platform": "infraforge",
        "deployed_by": "argocd",
        "provisioned_by": "crossplane",
    }


@app.get("/info")
def info():
    return {
        "hostname": os.environ.get("HOSTNAME", "unknown"),
        "namespace": os.environ.get("POD_NAMESPACE", "unknown"),
        "node": os.environ.get("NODE_NAME", "unknown"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
