const mysql = require('mysql2/promise');
const { Connector } = require('@google-cloud/cloud-sql-connector');

let pool = null;
let connector = null;

async function getPool() {
  if (pool) return pool;

  connector = new Connector();
  const clientOpts = await connector.getOptions({
    instanceConnectionName: process.env.INSTANCE_CONNECTION_NAME,
    ipType: 'PUBLIC',
  });

  pool = mysql.createPool({
    ...clientOpts,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
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
