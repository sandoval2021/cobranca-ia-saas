function log(level, message, meta = {}) {
  const entry = { level, message, time: new Date().toISOString(), ...meta };
  console.log(JSON.stringify(entry));
}
module.exports = { log };
