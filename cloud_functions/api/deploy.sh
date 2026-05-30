#!/bin/bash
cd "$(dirname "$0")" || exit

echo "Deploying SapaPNJ API to Google Cloud Run natively..."
gcloud run deploy sapapnjapi \
  --region=asia-southeast2 \
  --source=. \
  --allow-unauthenticated

echo "Deployment pipeline execution complete."
