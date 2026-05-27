# SAPA PNJ - INFRASTRUCTURE MIGRATION ROADMAP

**Objective:** Complete decoupling from Firebase/Cloudinary and transition to a unified Google Cloud Platform (GCP) architecture to enforce centralized computational offloading and relational data integrity.

## Phase 1: Media Storage Migration (Cloudinary -> Google Cloud Storage)
- [ ] Provision a GCS Bucket (`sapapnj-media-assets`) with appropriate IAM roles and CORS configuration.
- [ ] Rip out the Cloudinary SDK and obsolete environment variables (`CLOUDINARY_URL`, `API_KEY`, etc.).
- [ ] Implement secure signed URL generation in backend/Cloud Functions for secure direct-to-GCS uploads from the Flutter client.
- [ ] Migrate existing legacy assets from Cloudinary to the new GCS bucket via automated sync script.
- [ ] Update Flutter image parsing logic (`CachedNetworkImage` payloads) to dynamically accept GCS object URLs.

## Phase 2: Database Migration (Firebase Firestore -> Google Cloud SQL MySQL)
- [ ] Provision a Google Cloud SQL instance running MySQL 8+.
- [ ] Design the normalized relational schema (Users, Posts, Communities, Follows, Comments, Media).
- [ ] Write schema initialization migrations (using tools like Flyway, Prisma, or TypeORM on the backend layer).
- [ ] Develop an ETL pipeline to export NoSQL document graphs from Firestore and map them into relational MySQL tables.
- [ ] Tear down Flutter's direct `cloud_firestore` bindings.
- [ ] Implement a RESTful/gRPC API gateway to mediate all CRUD operations between the client and MySQL.

## Phase 3: Computational Offloading (On-Device -> Google Cloud Functions)
- [ ] Identify all in-app recommendation, sorting, and trending evaluation algorithms currently executing on the Dart thread (e.g., chronological sorting mapped against user preferences).
- [ ] Strip these hardcoded heuristic loops out of the Flutter client.
- [ ] Deploy serverless Cloud Functions (Node.js/Python) to handle heavy graph processing and relevance scoring.
- [ ] Reroute the Flutter frontend to trigger these Cloud Functions via HTTPS to fetch pre-calculated, sorted pagination data.
- [ ] Implement Redis/Memcached layer (Optional) at the Cloud Function level to cache heavy trending results.
