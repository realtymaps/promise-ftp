/* jshint node:true */
/* jshint -W097 */
'use strict';

module.exports = require('./dist/promiseFtp');
module.exports.FtpConnectionError = require('@motiz88/promise-ftp-common').FtpConnectionError;
module.exports.FtpReconnectError = require('@motiz88/promise-ftp-common').FtpReconnectError;
module.exports.STATUSES = require('@motiz88/promise-ftp-common').STATUSES;
module.exports.ERROR_CODES = require('./dist/errorCodes');
