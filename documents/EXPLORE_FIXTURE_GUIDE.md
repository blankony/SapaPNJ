# Explore Fixture Guide

Use this guide when you need to confirm that Trending and Discover work without manually creating posts in the app.

The fixture script is:

```text
cloud_functions/api/scripts/seed_explore_fixture.js
```

It writes deterministic test data into the configured Cloud SQL MySQL database, then prints a local preview of the expected trending and discovery results.

## What It Seeds

- A fixture viewer user, unless `SEED_VIEWER_UID` is provided.
- Seed author users.
- A seed community.
- Public posts with repeated hashtags and phrases for trending.
- Posts with different like and comment counts for discovery ranking.
- A community post with media.
- Old posts older than 7 days as trending negative controls.
- Private, followers-only, followed-author, and own-post negative controls for discovery.
- Likes and comments that match each seeded post's stored counters.

All generated IDs use the `seed_explore_` prefix.

## Environment

Run from the API folder:

```bash
cd cloud_functions/api
```

The script uses the same DB connection module as the API, so these variables must point to the database you want to test:

```bash
INSTANCE_CONNECTION_NAME=...
DB_USER=...
DB_PASS=...
DB_NAME=...
```

Use a dev or staging database. The script refuses to run unless `ALLOW_DEV_SEED=1` is set.

## Seed The Fixture

For DB-level preview only:

```bash
ALLOW_DEV_SEED=1 npm run seed:explore
```

For app/API verification with your real logged-in account, pass your SQL `users.uid`:

```bash
ALLOW_DEV_SEED=1 SEED_VIEWER_UID=your-user-uid npm run seed:explore
```

Use the `SEED_VIEWER_UID` version when you want `/api/explore/discover` and the Flutter Discover screen to use the exact same viewer assumptions as the fixture preview.

## Cleanup

Remove the fixture data with:

```bash
ALLOW_DEV_SEED=1 npm run seed:explore -- --cleanup
```

Cleanup deletes records with the `seed_explore_` prefix and relationships connected to those records. If `SEED_VIEWER_UID` was used, the real user row is not deleted.

## Verify Trending

Run:

```bash
curl -H "Authorization: Bearer $ID_TOKEN" "$API_BASE_URL/api/explore/trending"
```

Expected behavior:

- Recent repeated tags and phrases appear, such as `#uts`, `#krs`, `#magang`, `jadwal uts`, or `info magang`.
- `#oldtrend` and `#arsip` should not appear because those posts are older than 7 days.
- Counts should reflect how many seeded posts contain each trend, not raw word frequency.

## Verify Discovery

Run:

```bash
curl -H "Authorization: Bearer $ID_TOKEN" "$API_BASE_URL/api/explore/discover"
```

Expected behavior when your token UID matches `SEED_VIEWER_UID`:

- `seed_explore_post_community_robotics` should rank high because it is recent, has media, and has strong engagement.
- `seed_explore_post_hot_magang` and `seed_explore_post_media_beasiswa` should rank high from engagement and recency.
- `seed_explore_post_followed_hot` should be excluded because the viewer follows that author.
- `seed_explore_post_viewer_own` should be excluded because it belongs to the viewer.
- `seed_explore_post_private` should be excluded because it is private.
- `seed_explore_post_followers_only` should be excluded when the viewer does not follow that author.

The script also prints a discovery preview directly from the database so you can compare the endpoint response against it.

## Verify In The App

1. Seed with your real SQL user UID:

```bash
ALLOW_DEV_SEED=1 SEED_VIEWER_UID=your-user-uid npm run seed:explore
```

2. Log into the app as that same user.
3. Open Search.
4. Check Trending at PNJ for the seeded tags and phrases.
5. Open Discover For You and confirm the seeded high-scoring posts appear.
6. Confirm the negative-control posts listed above do not appear in Discover.

## Troubleshooting

- If the script says `Refusing to seed`, add `ALLOW_DEV_SEED=1`.
- If `SEED_VIEWER_UID` does not exist, log in once or create the SQL user first.
- If the endpoint response differs from the script preview, confirm the auth token UID matches `SEED_VIEWER_UID`.
- If dependencies are missing, run `npm install` in `cloud_functions/api`.
- If Cloud SQL connection fails locally, confirm your application-default credentials can access the configured instance.
