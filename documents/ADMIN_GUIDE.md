# SapaPNJ Admin Guide

## Overview

Admins can review and approve/reject student KTM (Kartu Tanda Mahasiswa) verification requests submitted by users.

## Admin Capabilities

- View all pending KTM verification requests
- Approve a user's verification (sets `verification_status` to `verified`)
- Reject a user's verification (sets `verification_status` to `rejected`)

## Default Admin

```
arnold.holyridho.runtuwene.te23@stu.pnj.ac.id
```

This user is set as admin by the migration `004_admin_ktm_pipeline.sql`.

## Managing Admin Privileges

### Grant admin role

```sql
UPDATE users SET role = 'admin' WHERE email = '<user_email>';
```

### Revoke admin role

```sql
UPDATE users SET role = 'user' WHERE email = '<user_email>';
```

## API Endpoints

All admin endpoints require:
- `Authorization: Bearer <firebase_id_token>` header
- The authenticated user must have `role = 'admin'` in the database

### GET /api/admin/verifications

Returns an array of users with `verification_status = 'pending'`.

**Response:**
```json
[
  {
    "uid": "...",
    "email": "...",
    "name": "...",
    "nim": "...",
    "ktm_image_url": "...",
    "verification_status": "pending",
    "profile_image_url": "...",
    "avatar_icon_id": 0,
    "avatar_hex": "",
    "department_code": "TE",
    "created_at": "2026-01-01T00:00:00.000Z"
  }
]
```

### PATCH /api/admin/verifications/:uid

Approve or reject a user's KTM verification.

**Request body:**
```json
{ "action": "approve" }
```
or
```json
{ "action": "reject" }
```

**Response:**
```json
{ "success": true, "verification_status": "verified" }
```

**Error (invalid action):** 400
```json
{ "error": "Invalid action. Must be \"approve\" or \"reject\"" }
```

## Verification Flow

1. User uploads KTM image via `PATCH /api/users/:uid` with `ktm_image_url` and sets `verification_status` to `pending`
2. Admin reviews pending verifications via `GET /api/admin/verifications`
3. Admin approves or rejects via `PATCH /api/admin/verifications/:uid`
4. User's `verification_status` is updated to `verified` or `rejected`
