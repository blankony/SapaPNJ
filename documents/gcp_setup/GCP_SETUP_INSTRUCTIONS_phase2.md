# SAPA PNJ — GCP Setup Instructions (Phase 2: Database Migration)

## Prerequisites

- **Phase 1 completed** (Cloud Functions deployed, GCS bucket configured)
- **Google Cloud SDK** (`gcloud` CLI) installed and authenticated
- `gcloud.conf` filled with your target project, region, Firebase project, and
  database values

---

## Step 0 — Load `gcloud.conf`

Run these commands from the repository root before following the rest of this
guide:

```bash
set -a
source gcloud.conf
set +a

gcloud config set project "$GCP_PROJECT_ID"
```

## Step 1 — Enable Cloud SQL API

```bash
gcloud services enable sqladmin.googleapis.com
gcloud services enable sql-component.googleapis.com
```

---

## Step 2 — Create the Cloud SQL Instance

```bash
# Create a MySQL 8.0 instance (db-f1-micro = cheapest tier)
# Region should match GCP_REGION from gcloud.conf.
gcloud sql instances create "$DB_INSTANCE" \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region="$GCP_REGION" \
  --storage-type=SSD \
  --storage-size=10GB \
  --availability-type=zonal \
  --assign-ip
```

> This takes **5–10 minutes**. Wait for it to complete.

Verify the instance is running:

```bash
gcloud sql instances describe "$DB_INSTANCE" --format="value(state)"
# Should output: RUNNABLE
```

---

## Step 3 — Create the Database and User

```bash
# Create the database
gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE"

# Create a user for the API (replace YOUR_PASSWORD with a strong password)
gcloud sql users create "$DB_USER" \
  --instance="$DB_INSTANCE" \
  --password=YOUR_PASSWORD
```

---

## Step 4 — Grant Cloud Functions Access to Cloud SQL

```bash
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

---

## Step 5 — Apply the Database Schema

Get the instance connection name:

```bash
gcloud sql instances describe "$DB_INSTANCE" --format="value(connectionName)"
# Output format: PROJECT_ID:REGION:DB_INSTANCE
```

Copy the output into `INSTANCE_CONNECTION_NAME` in `gcloud.conf`.

### Option A: Apply schema via `gcloud`

```bash
gcloud sql connect "$DB_INSTANCE" --user="$DB_USER"
```

Once connected:

```sql
USE your_database_name_from_gcloud_conf;
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

> **Important:** Use the `--env-vars-file` form below for API deployment so
> shell line wrapping cannot corrupt `DB_PASS` or `INSTANCE_CONNECTION_NAME`.

Create an env file for deployment. Keep `DB_PASS` outside `gcloud.conf` because
it is a server secret.

```bash
cat > /tmp/sapapnj-api-env.yaml <<EOF
DB_USER: $DB_USER
DB_PASS: YOUR_PASSWORD
DB_NAME: $DB_NAME
INSTANCE_CONNECTION_NAME: $INSTANCE_CONNECTION_NAME
FIREBASE_PROJECT_ID: $FIREBASE_PROJECT_ID
EOF
```

### Option A: Linux / macOS / GCP Cloud Shell (Bash)

```bash
gcloud functions deploy "$API_FUNCTION_NAME" \
  --gen2 \
  --runtime=nodejs22 \
  --region="$GCP_REGION" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point="$API_FUNCTION_NAME" \
  --env-vars-file=/tmp/sapapnj-api-env.yaml \
  --service-account="$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --source=. \
  --memory=256MB \
  --timeout=60s
```

### Option B: Windows PowerShell

```powershell
gcloud functions deploy "$env:API_FUNCTION_NAME" `
  --gen2 `
  --runtime=nodejs22 `
  --region="$env:GCP_REGION" `
  --trigger-http `
  --allow-unauthenticated `
  --entry-point="$env:API_FUNCTION_NAME" `
  --env-vars-file=/tmp/sapapnj-api-env.yaml `
  --service-account="${env:GCP_SERVICE_ACCOUNT}@${env:GCP_PROJECT_ID}.iam.gserviceaccount.com" `
  --source=. `
  --memory=256MB `
  --timeout=60s
```

### Option C: Single line (works everywhere)

```bash
gcloud functions deploy "$API_FUNCTION_NAME" --gen2 --runtime=nodejs22 --region="$GCP_REGION" --trigger-http --allow-unauthenticated --entry-point="$API_FUNCTION_NAME" --env-vars-file=/tmp/sapapnj-api-env.yaml --service-account="$GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" --source=. --memory=256MB --timeout=60s
```

### Repair existing environment variables

If you need to repair env vars after a password reset or broken deploy, use the file-based form:

```bash
cat > /tmp/sapapnj-api-env.yaml <<'EOF'
DB_USER: YOUR_DB_USER
DB_PASS: YOUR_PASSWORD
DB_NAME: YOUR_DB_NAME
INSTANCE_CONNECTION_NAME: PROJECT_ID:REGION:DB_INSTANCE
FIREBASE_PROJECT_ID: YOUR_FIREBASE_PROJECT_ID
EOF

gcloud functions deploy "$API_FUNCTION_NAME" \
  --gen2 \
  --region="$GCP_REGION" \
  --env-vars-file=/tmp/sapapnj-api-env.yaml
```

After deployment, note the URL:

```
https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME
```

This is your `API_BASE_URL`.

---

## Step 7 — Update `gcloud.conf`

Open `gcloud.conf` in the project root and add the actual API URL:

```env
API_BASE_URL=https://REGION-PROJECT_ID.cloudfunctions.net/FUNCTION_NAME
```

Use the actual URL from Step 6 output.

---

## Step 8 — Verify the API

### 1. Test health check

```bash
curl "$API_BASE_URL/api/health"
```

Expected response: `{"status":"ok"}`

### 2. Test authenticated endpoint

Requires a Firebase ID token:

```bash
curl -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  "$API_BASE_URL/api/users/YOUR_UID"
```

---

## Notes

- The Cloud SQL instance (`db-f1-micro`) costs **~$7–10/month**.
  - Stop when not in use: `gcloud sql instances patch "$DB_INSTANCE" --activation-policy=NEVER`
  - Restart: `gcloud sql instances patch "$DB_INSTANCE" --activation-policy=ALWAYS`
- The API uses `@google-cloud/cloud-sql-connector` for IAM-based auth. No need to manage SSL certificates or IP whitelists.
- For production, remove `--allow-unauthenticated` and enforce Firebase Auth token verification on all endpoints (already implemented in middleware).
