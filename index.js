/* jshint node:true */
/* jshint -W097 */
'use strict';


var coffee = require('coffee-script');
coffee.register();

module.exports = require('./lib/promiseFtp');
module.exports.FtpConnectionError = require('./lib/ftpConnectionError');
