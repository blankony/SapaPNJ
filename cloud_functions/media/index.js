const { Storage } = require("@google-cloud/storage");
const functions = require("@google-cloud/functions-framework");
const crypto = require("crypto");
const path = require("path");

const storage = new Storage();
const BUCKET_NAME = process.env.GCS_BUCKET_NAME || "sapapnj-media-assets";

// ---------------------------------------------------------------------------
// POST /getSignedUploadUrl
//   Body: { fileName: string, contentType: string }
//   Returns: { uploadUrl, objectName, contentType }
// ---------------------------------------------------------------------------
functions.http("getSignedUploadUrl", async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { fileName, contentType } = req.body;
    if (!fileName) {
      return res.status(400).json({ error: "fileName is required" });
    }

    // Generate a unique object name to avoid collisions.
    const ext = path.extname(fileName);
    const uniqueId = crypto.randomUUID();
    const objectName = `uploads/${uniqueId}${ext}`;

    const bucket = storage.bucket(BUCKET_NAME);
    const file = bucket.file(objectName);

    const resolvedContentType = contentType || "application/octet-stream";

    // Generate a signed URL valid for 15 minutes.
    const [url] = await file.getSignedUrl({
      version: "v4",
      action: "write",
      expires: Date.now() + 15 * 60 * 1000, // 15 min
      contentType: resolvedContentType,
    });

    return res.status(200).json({
      uploadUrl: url,
      objectName,
      contentType: resolvedContentType,
    });
  } catch (err) {
    console.error("getSignedUploadUrl error:", err);
    return res.status(500).json({ error: err.message });
  }
});

// ---------------------------------------------------------------------------
// POST /deleteObject
//   Body: { objectName: string }
//   Returns: { success: true }
// ---------------------------------------------------------------------------
functions.http("deleteObject", async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { objectName } = req.body;
    if (!objectName) {
      return res.status(400).json({ error: "objectName is required" });
    }

    const bucket = storage.bucket(BUCKET_NAME);
    await bucket.file(objectName).delete();

    return res.status(200).json({ success: true });
  } catch (err) {
    console.error("deleteObject error:", err);
    return res.status(500).json({ error: err.message });
  }
});
