/* jshint node:true */
/* jshint -W097 */
'use strict';


var coffee = require('coffee-script');
coffee.register();

module.exports = require('./lib/promiseFtp');
module.exports.FtpConnectionError = require('promise-ftp-errors').FtpConnectionError;
module.exports.FtpReconnectError = require('promise-ftp-errors').FtpReconnectError;
module.exports.STATUSES = require('./lib/connectionStatuses');
module.exports.ERROR_CODES = require('./lib/errorCodes');
