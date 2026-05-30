const express = require('express');
const cors = require('cors');
const functions = require('@google-cloud/functions-framework');
const { authMiddleware } = require('./middleware/auth');

const usersRouter = require('./routes/users');
const postRoutes = require('./routes/posts');
const communityRoutes = require('./routes/communities');
const exploreRoutes = require('./routes/explore');

const app = express();

// Middleware
app.use(cors({ origin: true }));
app.use(express.json());

// Health check (no auth)
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// All API routes require auth
app.use('/api/users', authMiddleware, usersRouter);
app.use('/api/posts', authMiddleware, postRoutes);
app.use('/api/communities', authMiddleware, communityRoutes);
app.use('/api/explore', authMiddleware, exploreRoutes);

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Export for Cloud Functions
functions.http('sapapnjApi', app);

// Also export for local testing
module.exports = app;
