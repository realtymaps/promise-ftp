### jshint node:true ###
### jshint -W097 ###
'use strict'


class FtpConnectionError extends Error
  constructor: (@message) ->
    super()
    @name = 'FtpConnectionError'

    
module.exports = FtpConnectionError
