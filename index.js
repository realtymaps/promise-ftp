/* jshint node:true */
/* jshint -W097 */
'use strict';


var coffee = require('coffee-script');
coffee.register();

module.exports = require('./lib/promiseFtp');
module.exports.FtpConnectionError = require('./lib/ftpConnectionError');
module.exports.FtpReconnectError = require('./lib/ftpReconnectError');
module.exports.STATUSES = require('./lib/connectionStatuses');
module.exports.ERROR_CODES = require('./lib/errorCodes');
