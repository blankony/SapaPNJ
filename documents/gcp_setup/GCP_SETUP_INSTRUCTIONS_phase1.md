# SAPA PNJ — GCP Setup Instructions (Phase 1: Media Storage Migration)

## Prerequisites

- **Google Cloud SDK** (`gcloud` CLI) installed — [Install Guide](https://cloud.google.com/sdk/docs/install)
- A GCP project (or create one below)
- **Node.js >= 18** (for Cloud Functions)

---

## Step 1 — GCP Project Setup

From the repository root, load `gcloud.conf` first. This keeps the guide usable
for any GCP project without editing commands one by one.

```bash
set -a
source gcloud.conf
set +a

# Authenticate with Google Cloud
gcloud auth login

# Create a new project (skip if you already have one)
gcloud projects create "$GCP_PROJECT_ID" --name="SapaPNJ"

# Set it as active
gcloud config set project "$GCP_PROJECT_ID"

# Enable required APIs
gcloud services enable storage.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
```

> **Note:** You must link a billing account (required for Cloud Functions).
> Go to: <https://console.cloud.google.com/billing> and link it to your project.

---

## Step 2 — Create the GCS Bucket

```bash
# Create the bucket (choose a region close to you)
gcloud storage buckets create "gs://$GCS_BUCKET_NAME" \
  --location="$GCP_REGION" \
  --default-storage-class=STANDARD \
  --uniform-bucket-level-access

# Make objects publicly readable (so CachedNetworkImage can fetch them)
gcloud storage buckets add-iam-policy-binding "gs://$GCS_BUCKET_NAME" \
  --member=allUsers \
  --role=roles/storage.objectViewer
```

### Set CORS

Create a `cors.json` file:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "PUT", "POST", "HEAD"],
    "responseHeader": ["Content-Type", "Content-Length"],
    "maxAgeSeconds": 3600
  }
]
```

Apply it:

```bash
gcloud storage buckets update "gs://$GCS_BUCKET_NAME" --cors-file=cors.json
```

---

## Step 3 — Create a Service Account for Cloud Functions

```bash
# Create the service account
gcloud iam service-accounts create "$GCP_SERVICE_ACCOUNT" \
  --display-name="SapaPNJ Media Functions"

# Grant it permission to sign URLs and manage the bucket
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

---

## Step 4 — Deploy the Cloud Functions

```bash
# Navigate to the cloud functions directory
cd cloud_functions/media

# Install dependencies
npm install
```

### Deploy `getSignedUploadUrl`

```bash
gcloud functions deploy getSignedUploadUrl \
  --gen2 \
  --runtime=nodejs22 \
  --region="$GCP_REGION" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=getSignedUploadUrl \
  --set-env-vars="GCS_BUCKET_NAME=$GCS_BUCKET_NAME" \
  --service-account="$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --source=.
```

### Deploy `deleteObject`

```bash
gcloud functions deploy deleteObject \
  --gen2 \
  --runtime=nodejs22 \
  --region="$GCP_REGION" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=deleteObject \
  --set-env-vars="GCS_BUCKET_NAME=$GCS_BUCKET_NAME" \
  --service-account="$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --source=.
```

After deployment, the URLs will look like:

```
https://$GCP_REGION-$GCP_PROJECT_ID.cloudfunctions.net/getSignedUploadUrl
https://$GCP_REGION-$GCP_PROJECT_ID.cloudfunctions.net/deleteObject
```

The **base URL** (without the function name) is what you need:

```
https://$GCP_REGION-$GCP_PROJECT_ID.cloudfunctions.net
```

---

## Step 5 — Update `gcloud.conf`

Open `gcloud.conf` in the project root and fill in the actual media values:

```env
GCS_BUCKET_NAME=your-gcs-bucket-name
GCS_FUNCTION_URL=https://REGION-PROJECT_ID.cloudfunctions.net
```

Use the actual base URL from Step 4 output.

---

## Step 6 — Verify Everything Works

### 1. Test the signed URL endpoint

```bash
curl -X POST "$GCS_FUNCTION_URL/getSignedUploadUrl" \
  -H "Content-Type: application/json" \
  -d '{"fileName": "test.png", "contentType": "image/png"}'
```

Expected response: a JSON with `uploadUrl`, `objectName`, `contentType`.

### 2. Test uploading a file

```bash
# Use the uploadUrl from the previous response
curl -X PUT "<uploadUrl>" \
  -H "Content-Type: image/png" \
  --data-binary @test.png
```

### 3. Verify the file is accessible

Open in browser:

```
https://storage.googleapis.com/YOUR_GCS_BUCKET_NAME/<objectName>
```

### 4. Test deletion

```bash
curl -X POST "$GCS_FUNCTION_URL/deleteObject" \
  -H "Content-Type: application/json" \
  -d '{"objectName": "<objectName>"}'
```

---

## Notes

- The Cloud Functions are set to `--allow-unauthenticated` for simplicity. For production, add Firebase Auth token verification in the function code.
- Region `asia-southeast2` is **Jakarta**. Common alternatives:
  | Region | Location |
  |---|---|
  | `asia-southeast1` | Singapore |
  | `us-central1` | Iowa |
  | `europe-west1` | Belgium |
- All media operations go through `lib/services/gcs_service.dart`.
