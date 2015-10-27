### jshint node:true ###
### jshint -W097 ###
'use strict'

FtpClient = require 'ftp'
Promise = require 'bluebird'
path = require 'path'

FtpConnectionError = require('promise-ftp-common').FtpConnectionError
FtpReconnectError = require('promise-ftp-common').FtpReconnectError
STATUSES = require('promise-ftp-common').STATUSES

simplePassthroughMethods = [
  'ascii'
  'binary'
  'abort'
  'delete'
  'status'
  'rename'
  'listSafe'
  'list'
  'get'
  'put'
  'append'
  'pwd'
  'mkdir'
  'rmdir'
  'system'
  'size'
  'lastMod'
  'restart'
]


class PromiseFtp

  constructor: () ->
    connectionStatus = STATUSES.NOT_YET_CONNECTED
    client = new FtpClient()
    ftpOptions = null
    autoReconnect = null
    preserveCwd = null
    intendedCwd = '.'
    lastError = null
    closeError = null
    reconnectError = null
    unexpectedClose = null
    autoReconnectPromise = null
    
    client.on 'error', (err) ->
      lastError = err
    client.on 'close', (hadError) ->
      if hadError
        closeError = lastError
      unexpectedClose = (connectionStatus != STATUSES.DISCONNECTING && connectionStatus != STATUSES.LOGGING_OUT)
      connectionStatus = STATUSES.DISCONNECTED
      autoReconnectPromise = null

    promisifiedClientMethods = {}
    for name in simplePassthroughMethods
      promisifiedClientMethods[name] = Promise.promisify(client[name], client)
      @[name] = do (name) -> (args...) ->
        checkConnection(name)
        .then () ->
          promisifiedClientMethods[name](args...)
    
    checkConnection = (methodName) => Promise.try () =>
      if unexpectedClose && autoReconnect && !autoReconnectPromise
        autoReconnectPromise = _connect(STATUSES.RECONNECTING)
      if autoReconnectPromise
        autoReconnectPromise
        .catch (err) ->
          throw new FtpReconnectError(closeError, err, false)
        .then () ->
          if preserveCwd
            promisifiedClientMethods.cwd(intendedCwd)
            .catch (err) =>
              @destroy()
              throw new FtpReconnectError(closeError, err, true)
      else if connectionStatus != STATUSES.CONNECTED
        throw new FtpConnectionError("can't perform '#{methodName}' command when connection status is: #{connectionStatus}")

    _connect = (tempStatus) -> new Promise (resolve, reject) ->
        connectionStatus = tempStatus
        reconnectError = null
        serverMessage = null
        client.once 'greeting', (msg) ->
          serverMessage = msg
        onReady = () ->
          client.removeListener('error', onError)
          connectionStatus = STATUSES.CONNECTED
          closeError = null
          unexpectedClose = false
          resolve(serverMessage)
        onError = (err) ->
          client.removeListener('ready', onReady)
          reject(err)
        client.once('ready', onReady)
        client.once('error', onError)
        client.connect(ftpOptions)
    
    @connect = (options) ->
      if connectionStatus != STATUSES.NOT_YET_CONNECTED && connectionStatus != STATUSES.DISCONNECTED
        throw new FtpConnectionError("can't connect when connection status is: '#{connectionStatus}'")
      # copy options object so options can't change without another call to @connect()
      ftpOptions = {}
      for key,value of options
        ftpOptions[key] = value
      # deep copy options.secureOptions... or at least mostly, ignoring the possibility of mutable secureOptions fields
      if options.secureOptions
        ftpOptions.secureOptions = {}
        for key,value of options.secureOptions
          ftpOptions.secureOptions[key] = value
      # the following options are part of PromiseFtp, so they're not understood by the underlying client
      autoReconnect = !!options.autoReconnect
      delete ftpOptions.autoReconnect
      preserveCwd = !!options.preserveCwd
      delete ftpOptions.preserveCwd
      # now that everything is set up, we can connect
      _connect(STATUSES.CONNECTING)
  
    @reconnect = () ->
      if connectionStatus != STATUSES.NOT_YET_CONNECTED && connectionStatus != STATUSES.DISCONNECTED
        throw new FtpConnectionError("can't reconnect when connection status is: '#{connectionStatus}'")
      _connect(STATUSES.RECONNECTING)

    @logout = () ->
      connectionStatus = STATUSES.LOGGING_OUT
      promisifiedClientMethods.logout()

    @end = () -> new Promise (resolve, reject) ->
      if connectionStatus == STATUSES.NOT_YET_CONNECTED || connectionStatus == STATUSES.DISCONNECTED
        reject(new FtpConnectionError("can't end connection when connection status is: #{connectionStatus}"))
      connectionStatus = STATUSES.DISCONNECTING
      client.once 'close', (hadError) ->
        resolve(if hadError then lastError||true else false)
      client.end()
  
    @destroy = () ->
      if connectionStatus == STATUSES.NOT_YET_CONNECTED || connectionStatus == STATUSES.DISCONNECTED
        wasDisconnected = true
      else
        wasDisconnected = false
        connectionStatus = STATUSES.DISCONNECTING
      client.destroy()
      wasDisconnected

    @getConnectionStatus = () ->
      connectionStatus

    reconnectMethodHandlers = {}
    
    reconnectMethodHandlers.site = (command) ->
      promisifiedClientMethods.site(command)
      .spread (text, code) ->
        text: text
        code: code

    reconnectMethodHandlers.cwd = (dir) ->
      promisifiedClientMethods.cwd(dir)
      .then (result) ->
        if dir.charAt(0) == '/'
          intendedCwd = path.normalize(dir)
        else
          intendedCwd = path.join(intendedCwd, dir)
        result

    reconnectMethodHandlers.cdup = () ->
      promisifiedClientMethods.cdup()
      .then (result) ->
        intendedCwd = path.join(intendedCwd, '..')
        result

    for name,handler of reconnectMethodHandlers
      promisifiedClientMethods[name] = Promise.promisify(client[name], client)
      @[name] = do (name,handler) -> (args...) ->
        checkConnection(name)
        .then () ->
          handler(args...)


module.exports = PromiseFtp
