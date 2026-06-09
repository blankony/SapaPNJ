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

### 4. Navigate to the API folder

```bash
cd cloud_functions/api
```

### 5. Deploy to Cloud Run

```bash
gcloud run deploy sapapnjapi --region=asia-southeast2 --source=. --allow-unauthenticated
```

### 6. Handle prompts

- If prompted to select a project, choose your GCP project.
- If prompted to enable APIs, type `Y`.

### 7. Wait for completion

Build and deployment usually takes **2–5 minutes**.

### 8. Done

The new endpoint will be live at your Cloud Run URL.

---

## Verifying the Deployment

In Cloud Shell, test the health endpoint:

```bash
curl https://YOUR_CLOUD_RUN_URL/api/health
```

Expected response:

```json
{"status":"ok","timestamp":"..."}
```
