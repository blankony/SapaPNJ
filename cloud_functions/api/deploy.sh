#!/bin/bash
cd "$(dirname "$0")" || exit

echo "Deploying SapaPNJ API to Google Cloud Functions (Gen 2)..."
gcloud functions deploy sapapnjapi \
  --gen2 \
  --region=asia-southeast2 \
  --runtime=nodejs18 \
  --entry-point=sapapnjApi \
  --source=. \
  --trigger-http \
  --allow-unauthenticated

echo "Deployment pipeline execution complete."
