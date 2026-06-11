# How to Deploy the SapaPNJ Backend API

> Deployment target: **Google Cloud Run** via GCP Cloud Shell.

## When to Deploy

- **Redeploy required:** When backend files (`cloud_functions/api/`) are changed.
- **No redeploy needed:** Flutter-only changes.

---

## Deployment Steps

### 1. Push your latest code to GitHub

```bash
git push
```

### 2. Open GCP Cloud Shell

Navigate to: <https://shell.cloud.google.com>

### 3. Clone or pull the repo in Cloud Shell

**First time:**

```bash
git clone https://github.com/YOUR_USERNAME/SapaPNJ.git
cd SapaPNJ
```

**Already cloned before:**

```bash
cd SapaPNJ
git pull
```

### 4. Load deployment config

`gcloud.conf` is the source of truth for project, region, service name, Firebase
project ID, and Cloud SQL connection name. Review it before deploying:

```bash
set -a
source gcloud.conf
set +a

gcloud config set project "$GCP_PROJECT_ID"
```

### 5. Navigate to the API folder

```bash
cd cloud_functions/api
```

Set the database password only in your shell. Do not commit it to `gcloud.conf`
or `.env`.

```bash
export DB_PASS="YOUR_DATABASE_PASSWORD"
```

### 6. Deploy to Cloud Run

Use the deploy helper. It reads `gcloud.conf`, requires `DB_PASS`, and deploys
to the configured project and region.

```bash
./deploy.sh
```

Equivalent manual command:

```bash
gcloud run deploy "$API_SERVICE_NAME" \
  --project="$GCP_PROJECT_ID" \
  --region="$GCP_REGION" \
  --source=. \
  --allow-unauthenticated \
  --set-env-vars="DB_USER=$DB_USER,DB_PASS=$DB_PASS,DB_NAME=$DB_NAME,INSTANCE_CONNECTION_NAME=$INSTANCE_CONNECTION_NAME,FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID"
```

### 7. Handle prompts

- If prompted to select a project, choose your GCP project.
- If prompted to enable APIs, type `Y`.

### 8. Wait for completion

Build and deployment usually takes **2–5 minutes**.

### 9. Update `gcloud.conf`

After deployment, copy the Cloud Run service URL into `API_BASE_URL` in
`gcloud.conf`, then rebuild/redeploy the Flutter client.

---

## Verifying the Deployment

In Cloud Shell, test the health endpoint:

```bash
curl "$API_BASE_URL/api/health"
```

Expected response:

```json
{"status":"ok","timestamp":"..."}
```
