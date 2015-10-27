### jshint node:true ###
### jshint -W097 ###
'use strict'


class FtpReconnectError extends Error
  constructor: (@disconnectError='', @connectError='', onCwd) ->
    @name = 'FtpReconnectError'
    prefix = "Error automatically reconnecting to server"
    suffix = "Triggering disconnect error"
    if onCwd
      mainMsg = "Could not connect to server"
    else
      mainMsg = "Could not preserve CWD"
    @message = "#{prefix}.  #{mainMsg}: #{@connectError}.  #{suffix}: #{@disconnectError}."
    connectErrorStack = "#{@connectError.stack||@connectError}"
    if connectErrorStack[-1..-1] != '\n'
      connectErrorStack += '\n'
    disconnectErrorStack = "#{@disconnectError.stack||@disconnectError}"
    if disconnectErrorStack[-1..-1] != '\n'
      disconnectErrorStack += '\n'
    @stack = "#{@name}: #{prefix}.\n#{mainMsg}: #{connectErrorStack}#{suffix}: #{disconnectErrorStack}"


module.exports = FtpReconnectError
