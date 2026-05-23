const { randomUUID } = require('crypto');
const db = { companies: [], apps: [], servers: [], routes: [], customers: [], credentials: [], history: [] };
const now = () => new Date().toISOString();
const id = () => randomUUID();
module.exports = { db, now, id };
