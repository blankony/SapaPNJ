# SAPA PNJ - INFRASTRUCTURE MIGRATION ROADMAP

**Objective:** Complete decoupling from Firebase/Cloudinary and transition to a unified Google Cloud Platform (GCP) architecture to enforce centralized computational offloading and relational data integrity.

## Phase 1: Media Storage Migration (Cloudinary -> Google Cloud Storage)
- [x] Provision a GCS Bucket (`sapapnj-media-assets`) with appropriate IAM roles and CORS configuration. *(see documents/gcp_setup/GCP_SETUP_INSTRUCTIONS_phase1.txt)*
- [x] Rip out the Cloudinary SDK and obsolete environment variables (`CLOUDINARY_URL`, `API_KEY`, etc.).
- [x] Implement secure signed URL generation in backend/Cloud Functions for secure direct-to-GCS uploads from the Flutter client.
- [x] ~~Migrate existing legacy assets from Cloudinary to the new GCS bucket via automated sync script.~~ *(Skipped — no legacy assets to migrate)*
- [x] Update Flutter image parsing logic (`CachedNetworkImage` payloads) to dynamically accept GCS object URLs.

## Phase 2: Database Migration (Firebase Firestore -> Google Cloud SQL MySQL)
- [x] Provision a Google Cloud SQL instance running MySQL 8+.
- [x] Design the normalized relational schema (Users, Posts, Communities, Follows, Comments, Media).
- [x] Write schema initialization migrations (using tools like Flyway, Prisma, or TypeORM on the backend layer).
- [x] Develop an ETL pipeline to export NoSQL document graphs from Firestore and map them into relational MySQL tables.
- [x] Tear down Flutter's direct `cloud_firestore` bindings.
- [x] Implement a RESTful/gRPC API gateway to mediate all CRUD operations between the client and MySQL.

## Phase 3: Computational Offloading (On-Device -> Google Cloud Functions)
- [x] Identify all in-app recommendation, sorting, and trending evaluation algorithms currently executing on the Dart thread (e.g., chronological sorting mapped against user preferences).
- [x] Strip these hardcoded heuristic loops out of the Flutter client.
- [x] Deploy serverless Cloud Functions (Node.js/Python) to handle heavy graph processing and relevance scoring.
- [x] Reroute the Flutter frontend to trigger these Cloud Functions via HTTPS to fetch pre-calculated, sorted pagination data.
- [ ] Implement Redis/Memcached layer (Optional) at the Cloud Function level to cache heavy trending results.

## Phase 4: Admin KTM Verification Pipeline

### 4.1 Database Schema Changes
- [ ] Add `role ENUM('user','admin') DEFAULT 'user'` column to `users` table
- [ ] Add `ktm_image_url TEXT` column to `users` table
- [ ] Modify `verification_status` ENUM to include `'rejected'`: `ENUM('none','pending','verified','rejected')`
- [ ] Update schema.sql to reflect all changes

### 4.2 Backend API — Admin Routes
- [ ] Create admin middleware (`middleware/admin.js`) — checks `role = 'admin'` from DB
- [ ] Create `/api/admin/verifications` route file (`routes/admin.js`)
- [ ] `GET /api/admin/verifications` — list all users with `verification_status = 'pending'` (admin only)
- [ ] `PATCH /api/admin/verifications/:uid` — approve or reject a user (sets `verification_status` to `'verified'` or `'rejected'`) (admin only)
- [ ] Register admin routes in `index.js`
- [ ] Add `ktm_image_url` to allowed PATCH fields in `routes/users.js`

### 4.3 Flutter Client — Fix KTM Submission
- [ ] Fix `ktm_verification_screen.dart` to store `ktm_image_url` alongside `verification_status: 'pending'`

### 4.4 Flutter Client — Admin API Methods
- [ ] Add `getPendingVerifications()` method to `ApiService`
- [ ] Add `reviewVerification(uid, approve)` method to `ApiService`
- [ ] Add `getMyRole()` or use existing `getUser()` to detect admin role

### 4.5 Flutter Client — Admin Panel Screen
- [ ] Create `admin_panel_screen.dart` — list pending KTM verifications with image preview
- [ ] Each card shows: user name, NIM, email, KTM image, approve/reject buttons
- [ ] Add "Admin Panel" menu item in `account_center_page.dart` (only visible when `role == 'admin'`)

### 4.6 Set Initial Admin & Documentation
- [ ] Set user `arnold.holyridho.runtuwene.te23@stu.pnj.ac.id` as admin in migration SQL
- [ ] Create `documents/ADMIN_GUIDE.md` documenting how to add/remove admin users

## Bugs
- [x] Replies on the blogpost page constantly refresh during typing instead of just refreshing after sending a message or manual refresh
- [x] On the profile page the replies is not showing anything at all.
- [x] Home screen bug, where the first post showing doest acknowledge the appbar and instead it is show under instead of below stacking the top appbar, this happes when a post was deleted and the page was refreshed then the user refresh the page it after refreshing it just load the home page while loading the post under the top appbar making the UI looks janky
- [x] The Communities page cannot be refreshed(pull down gesture)
- [x] The Communities Comunity account page and clicking on the banner even if it says "Add Banner" does not prompt the user to choose an image as banner.
- [ ] Change the gear icon on the community page to a pen for more clearer icon and suggesting we can edit the comunity profile and roles from here
- [ ] In the comunities page the "Your Channels" Section even after setting a profile image for it, still doesnt have a image at all and instead still showing the comunity name first letter placeholder icon
- [ ] Spirit AI, when loading a history it only show the messages from the AI and no messages from the user is shown at all.
- [ ] Optimize spirit AI Token usage by summarizing the whole chat after every each 10 message. this way Spirit AI can still remember and the prompt we sent will be shorter with the context.
- [ ] Profile page bug, when at we are top of the profile page the topbar/appbar is showing when it should be hidden, and then when we scroll the top bar became hidden instead, it is essentially flipped.
- [ ] Verification method for KTM, Official Comunities, etc