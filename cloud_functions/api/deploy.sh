#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")" || exit
ROOT_DIR="$(cd ../.. && pwd)"

set -a
# shellcheck disable=SC1091
source "$ROOT_DIR/gcloud.conf"
set +a

: "${GCP_PROJECT_ID:?Missing GCP_PROJECT_ID in gcloud.conf}"
: "${GCP_REGION:?Missing GCP_REGION in gcloud.conf}"
: "${API_SERVICE_NAME:?Missing API_SERVICE_NAME in gcloud.conf}"
: "${DB_USER:?Missing DB_USER in gcloud.conf}"
: "${DB_NAME:?Missing DB_NAME in gcloud.conf}"
: "${INSTANCE_CONNECTION_NAME:?Missing INSTANCE_CONNECTION_NAME in gcloud.conf}"
: "${FIREBASE_PROJECT_ID:?Missing FIREBASE_PROJECT_ID in gcloud.conf}"
: "${DB_PASS:?Set DB_PASS in your shell before running deploy.sh}"

echo "Deploying SapaPNJ API to Google Cloud Run..."
gcloud run deploy "$API_SERVICE_NAME" \
  --project="$GCP_PROJECT_ID" \
  --region="$GCP_REGION" \
  --source=. \
  --allow-unauthenticated \
  --set-env-vars="DB_USER=$DB_USER,DB_PASS=$DB_PASS,DB_NAME=$DB_NAME,INSTANCE_CONNECTION_NAME=$INSTANCE_CONNECTION_NAME,FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID"

echo "Deployment pipeline execution complete."
