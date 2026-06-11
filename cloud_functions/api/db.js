const mysql = require('mysql2/promise');
const { Connector } = require('@google-cloud/cloud-sql-connector');

let pool = null;
let connector = null;

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

async function getPool() {
  if (pool) return pool;

  connector = new Connector();
  const clientOpts = await connector.getOptions({
    instanceConnectionName: requireEnv('INSTANCE_CONNECTION_NAME'),
    ipType: 'PUBLIC',
  });

  pool = mysql.createPool({
    ...clientOpts,
    user: requireEnv('DB_USER'),
    password: requireEnv('DB_PASS'),
    database: requireEnv('DB_NAME'),
    waitForConnections: true,
    connectionLimit: 5,
    queueLimit: 0,
  });

  return pool;
}

async function closePool() {
  const activePool = pool;
  const activeConnector = connector;

  pool = null;
  connector = null;

  if (activePool) {
    await activePool.end();
  }

  if (activeConnector) {
    activeConnector.close();
  }
}

module.exports = { getPool, closePool };
