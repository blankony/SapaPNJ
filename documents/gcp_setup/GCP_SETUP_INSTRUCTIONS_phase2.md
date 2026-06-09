# SAPA PNJ — GCP Setup Instructions (Phase 2: Database Migration)

## Prerequisites

- **Phase 1 completed** (Cloud Functions deployed, GCS bucket configured)
- **Google Cloud SDK** (`gcloud` CLI) installed and authenticated
- Active project: `sapapnj-gcp`

---

## Step 1 — Enable Cloud SQL API

```bash
gcloud services enable sqladmin.googleapis.com
gcloud services enable sql-component.googleapis.com
```

---

## Step 2 — Create the Cloud SQL Instance

```bash
# Create a MySQL 8.0 instance (db-f1-micro = cheapest tier)
# Region: asia-southeast2 (Jakarta) — same as your Cloud Functions
gcloud sql instances create sapapnj-db \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region=asia-southeast2 \
  --storage-type=SSD \
  --storage-size=10GB \
  --availability-type=zonal \
  --assign-ip
```

> This takes **5–10 minutes**. Wait for it to complete.

Verify the instance is running:

```bash
gcloud sql instances describe sapapnj-db --format="value(state)"
# Should output: RUNNABLE
```

---

## Step 3 — Create the Database and User

```bash
# Create the database
gcloud sql databases create sapapnj --instance=sapapnj-db

# Create a user for the API (replace YOUR_PASSWORD with a strong password)
gcloud sql users create sapapnj-api \
  --instance=sapapnj-db \
  --password=YOUR_PASSWORD
```

---

## Step 4 — Grant Cloud Functions Access to Cloud SQL

```bash
gcloud projects add-iam-policy-binding sapapnj-gcp \
  --member="serviceAccount:sapapnj-media-fn@sapapnj-gcp.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

---

## Step 5 — Apply the Database Schema

Get the instance connection name:

```bash
gcloud sql instances describe sapapnj-db --format="value(connectionName)"
# Output: sapapnj-gcp:asia-southeast2:sapapnj-db
```

### Option A: Apply schema via `gcloud`

```bash
gcloud sql connect sapapnj-db --user=sapapnj-api
```

Once connected:

```sql
USE sapapnj;
-- Paste the contents of cloud_functions/api/schema.sql
```

### Option B: Use Cloud SQL Proxy locally

See: <https://cloud.google.com/sql/docs/mysql/sql-proxy>

---

## Step 6 — Deploy the API Gateway

```bash
# Navigate to the API directory
cd cloud_functions/api

# Install dependencies
npm install
```

> **Important:** Keep the entire `--set-env-vars` value as one shell argument. Do not press Enter inside `DB_USER`, `DB_PASS`, `DB_NAME`, or `INSTANCE_CONNECTION_NAME`.

### Option A: Linux / macOS / GCP Cloud Shell (Bash)

```bash
gcloud functions deploy sapapnjApi \
  --gen2 \
  --runtime=nodejs22 \
  --region=asia-southeast2 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=sapapnjApi \
  --set-env-vars="DB_USER=sapapnj-api,DB_PASS=REDACTED,DB_NAME=sapapnj,INSTANCE_CONNECTION_NAME=sapapnj-gcp:asia-southeast2:sapapnj-db" \
  --service-account=sapapnj-media-fn@sapapnj-gcp.iam.gserviceaccount.com \
  --source=. \
  --memory=256MB \
  --timeout=60s
```

### Option B: Windows PowerShell

```powershell
gcloud functions deploy sapapnjApi `
  --gen2 `
  --runtime=nodejs22 `
  --region=asia-southeast2 `
  --trigger-http `
  --allow-unauthenticated `
  --entry-point=sapapnjApi `
  --set-env-vars="DB_USER=sapapnj-api,DB_PASS=REDACTED,DB_NAME=sapapnj,INSTANCE_CONNECTION_NAME=sapapnj-gcp:asia-southeast2:sapapnj-db" `
  --service-account=sapapnj-media-fn@sapapnj-gcp.iam.gserviceaccount.com `
  --source=. `
  --memory=256MB `
  --timeout=60s
```

### Option C: Single line (works everywhere)

```bash
gcloud functions deploy sapapnjApi --gen2 --runtime=nodejs22 --region=asia-southeast2 --trigger-http --allow-unauthenticated --entry-point=sapapnjApi --set-env-vars="DB_USER=sapapnj-api,DB_PASS=YOUR_PASSWORD,DB_NAME=sapapnj,INSTANCE_CONNECTION_NAME=sapapnj-gcp:asia-southeast2:sapapnj-db" --service-account=sapapnj-media-fn@sapapnj-gcp.iam.gserviceaccount.com --source=. --memory=256MB --timeout=60s
```

### Repair existing environment variables

If you need to repair env vars after a password reset or broken deploy, use the file-based form:

```bash
cat > /tmp/sapapnj-api-env.yaml <<'EOF'
DB_USER: sapapnj-api
DB_PASS: YOUR_PASSWORD
DB_NAME: sapapnj
INSTANCE_CONNECTION_NAME: sapapnj-gcp:asia-southeast2:sapapnj-db
EOF

gcloud functions deploy sapapnjApi \
  --gen2 \
  --region=asia-southeast2 \
  --env-vars-file=/tmp/sapapnj-api-env.yaml
```

After deployment, note the URL:

```
https://asia-southeast2-sapapnj-gcp.cloudfunctions.net/sapapnjApi
```

This is your `API_BASE_URL`.

---

## Step 7 — Update Your `.env` File

Open the `.env` file in the project root and add:

```env
API_BASE_URL=https://asia-southeast2-sapapnj-gcp.cloudfunctions.net/sapapnjApi
```

Use the actual URL from Step 6 output.

---

## Step 8 — Verify the API

### 1. Test health check

```bash
curl https://asia-southeast2-sapapnj-gcp.cloudfunctions.net/sapapnjApi/api/health
```

Expected response: `{"status":"ok"}`

### 2. Test authenticated endpoint

Requires a Firebase ID token:

```bash
curl -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  https://asia-southeast2-sapapnj-gcp.cloudfunctions.net/sapapnjApi/api/users/YOUR_UID
```

---

## Notes

- The Cloud SQL instance (`db-f1-micro`) costs **~$7–10/month**.
  - Stop when not in use: `gcloud sql instances patch sapapnj-db --activation-policy=NEVER`
  - Restart: `gcloud sql instances patch sapapnj-db --activation-policy=ALWAYS`
- The API uses `@google-cloud/cloud-sql-connector` for IAM-based auth. No need to manage SSL certificates or IP whitelists.
- For production, remove `--allow-unauthenticated` and enforce Firebase Auth token verification on all endpoints (already implemented in middleware).
