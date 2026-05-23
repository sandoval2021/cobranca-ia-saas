class AppError extends Error {
  constructor(message, status = 400, code = 'erro_aplicacao') {
    super(message);
    this.status = status;
    this.code = code;
  }
}
module.exports = { AppError };
