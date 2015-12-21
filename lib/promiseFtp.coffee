### jshint node:true ###
### jshint -W097 ###
'use strict'


FtpClient = require('ftp')
path = require('path')

FtpConnectionError = require('promise-ftp-common').FtpConnectionError
FtpReconnectError = require('promise-ftp-common').FtpReconnectError
STATUSES = require('promise-ftp-common').STATUSES


# these methods need no custom logic; just wrap the common promise, connection-check, and reconnect logic around the
# originals and pass through any args
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

# these methods will have custom logic defined, and then will be wrapped in common promise, connection-check, and
# reconnect logic
complexPassthroughMethods = [
  'site'
  'cwd'
  'cdup'
]

# these methods do not use the common wrapper; they're listed here in order to be properly set on the prototype
otherPrototypeMethods = [
  'connect'
  'reconnect'
  'logout'
  'end'
  'destroy'
  'getConnectionStatus'
]


class PromiseFtp

  constructor: () ->
    if @ not instanceof PromiseFtp
      throw new TypeError("PromiseFtp constructor called without 'new' keyword")
    
    connectionStatus = STATUSES.NOT_YET_CONNECTED
    client = new FtpClient()
    connectOptions = null
    autoReconnect = null
    preserveCwd = null
    intendedCwd = '.'
    lastError = null
    closeError = null
    unexpectedClose = null
    autoReconnectPromise = null
    promisifiedClientMethods = {}
    
    
    # always-on event handlers
    client.on 'error', (err) ->
      lastError = err
    client.on 'close', (hadError) ->
      if hadError
        closeError = lastError
      unexpectedClose = (connectionStatus != STATUSES.DISCONNECTING && connectionStatus != STATUSES.LOGGING_OUT)
      connectionStatus = STATUSES.DISCONNECTED
      autoReconnectPromise = null
      
    
    # internal connect logic
    _connect = (tempStatus) -> new Promise (resolve, reject) ->
      connectionStatus = tempStatus
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
      client.connect(connectOptions)
    
      
    # methods listed in otherPrototypeMethods, which don't get a wrapper
    
    @connect = (options) -> Promise.resolve().then () ->
      if connectionStatus != STATUSES.NOT_YET_CONNECTED && connectionStatus != STATUSES.DISCONNECTED
        throw new FtpConnectionError("can't connect when connection status is: '#{connectionStatus}'")
      # copy options object so options can't change without another call to @connect()
      connectOptions = {}
      for key,value of options
        connectOptions[key] = value
      # deep copy options.secureOptions... or at least mostly, ignoring the possibility of mutable secureOptions fields
      if options.secureOptions
        connectOptions.secureOptions = {}
        for key,value of options.secureOptions
          connectOptions.secureOptions[key] = value
      # the following options are part of PromiseFtp, so they're not understood by the underlying client
      autoReconnect = !!options.autoReconnect
      delete connectOptions.autoReconnect
      preserveCwd = !!options.preserveCwd
      delete connectOptions.preserveCwd
      # now that everything is set up, we can connect
      _connect(STATUSES.CONNECTING)
  
    @reconnect = () -> Promise.resolve().then () ->
      if connectionStatus != STATUSES.NOT_YET_CONNECTED && connectionStatus != STATUSES.DISCONNECTED
        throw new FtpConnectionError("can't reconnect when connection status is: '#{connectionStatus}'")
      _connect(STATUSES.RECONNECTING)

    @logout = () ->
      wait = if autoReconnectPromise then autoReconnectPromise else Promise.resolve()
      wait
      .then () ->
        if connectionStatus == STATUSES.NOT_YET_CONNECTED || connectionStatus == STATUSES.DISCONNECTED || connectionStatus == STATUSES.DISCONNECTING
          throw new FtpConnectionError("can't log out when connection status is: #{connectionStatus}")
        connectionStatus = STATUSES.LOGGING_OUT
        promisifiedClientMethods.logout()

    @end = () -> new Promise (resolve, reject) ->
      if connectionStatus == STATUSES.NOT_YET_CONNECTED || connectionStatus == STATUSES.DISCONNECTED
        return reject(new FtpConnectionError("can't end connection when connection status is: #{connectionStatus}"))
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

    
    # methods listed in complexPassthroughMethods, which will get a common logic wrapper
    
    @site = (command) ->
      promisifiedClientMethods.site(command)
      .spread (text, code) ->
        { text, code }

    @cwd = (dir) ->
      promisifiedClientMethods.cwd(dir)
      .then (result) ->
        if dir.charAt(0) == '/'
          intendedCwd = path.normalize(dir)
        else
          intendedCwd = path.join(intendedCwd, dir)
        result

    @cdup = () ->
      promisifiedClientMethods.cdup()
      .then (result) ->
        intendedCwd = path.join(intendedCwd, '..')
        result

    
    # common promise, connection-check, and reconnect logic
    commonLogicFactory = (name, handler) ->
      promisifiedClientMethods[name] = (args...) ->
        new Promise (resolve, reject) ->
          client[name] (err, res) ->
            if err then reject err else resolve(res)
      if !handler
        handler = promisifiedClientMethods[name]
      (args...) ->
        Promise.resolve().then () =>
          # if we need to reconnect and we're not already reconnecting, start reconnect
          if unexpectedClose && autoReconnect && !autoReconnectPromise
            autoReconnectPromise = _connect(STATUSES.RECONNECTING)
            .catch (err) ->
              throw new FtpReconnectError(closeError, err, false)
            .then () ->
              if preserveCwd
                promisifiedClientMethods.cwd(intendedCwd)
                .catch (err) =>
                  @destroy()
                  throw new FtpReconnectError(closeError, err, true)
              else
                intendedCwd = '.'
          # if we just started reconnecting or were already reconnecting, wait for that to finish before continuing
          if autoReconnectPromise
            return autoReconnectPromise
          else if connectionStatus != STATUSES.CONNECTED
            throw new FtpConnectionError("can't perform '#{name}' command when connection status is: #{connectionStatus}")
        .then () ->
          # now perform the requested command
          handler(args...)

    # create the methods listed in simplePassthroughMethods as common logic wrapped around the original client method
    for name in simplePassthroughMethods
      @[name] = commonLogicFactory(name)

    # wrap the methods listed in complexPassthroughMethods with common logic
    for name in complexPassthroughMethods
      @[name] = commonLogicFactory(name, @[name])

  
  # set method names on the prototype; they'll be overwritten with real functions from inside the constructor's closure
  for methodList in [simplePassthroughMethods, complexPassthroughMethods, otherPrototypeMethods]
    for methodName in methodList
      PromiseFtp.prototype[methodName] = null


module.exports = PromiseFtp
