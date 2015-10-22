### jshint node:true ###
### jshint -W097 ###
'use strict'

VError = require 'verror'


class FtpConnectionError extends VError
  constructor: (args...) ->
    super(args...)
    @name = 'FtpConnectionError'

    
module.exports = FtpConnectionError
