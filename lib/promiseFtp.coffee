### jshint node:true ###
### jshint -W097 ###
'use strict'

FtpClient = require 'ftp'
Promise = require 'bluebird'
_ = require 'lodash'

FtpConnectionError = require './ftpConnectionError'


simplePassthroughMethods = [
  'ascii'
  'binary'
  'abort'
  'cwd'
  'delete'
  'status'
  'rename'
  'logout'
  'listSafe'
  'list'
  'get'
  'put'
  'append'
  'pwd'
  'cdup'
  'mkdir'
  'rmdir'
  'system'
  'size'
  'lastMod'
  'restart'
]


class PromiseFtp

  constructor: () ->
    @options = null
    @name = "PromiseFtp"
    @serverMessage = undefined
    @connected = false
    @closedWithError = false
    @errors = []

    @client = new FtpClient()
    @client.on 'greeting', (msg) =>
      @serverMessage = msg
    @client.on 'close', (hadError) =>
      @connected = false
      if hadError
        @closedWithError = true
    @client.once 'error', (err) =>
      @errors.push(err)

    promisifiedMethods = {}

    for name in simplePassthroughMethods
      promisifiedMethods[name] = Promise.promisify(FtpClient.prototype[name], @client)
      @[name] = do (name) => (args...) =>
        if !@connected
          return Promise.reject(new FtpConnectionError("client not currently connected"))
        promisifiedMethods[name](args...)
    promisifiedMethods.site = Promise.promisify(@client.site, @client)
    @site = (args...) =>
      if !@connected
        return Promise.reject(new FtpConnectionError("client not currently connected"))
      promisifiedMethods.site(args...)
      .spread (text, code) ->
        text: text
        code: code


  connect: (options) -> new Promise (resolve, reject) =>
    doneConnecting = false
    if @connected
      return reject(new FtpConnectionError("client currently connected to: #{@options.host}"))
    @options = options
    @serverMessage = undefined
    @connected = false
    @closedWithError = false
    @errors = []
    readyListener = () =>
      doneConnecting = true
      @connected = true
      resolve(@serverMessage)
    @client.once 'ready', readyListener
    @client.once 'error', (err) =>
      if !doneConnecting
        @client.removeListener 'ready', readyListener
        reject(err)
    @client.connect @options
  
  end: () -> new Promise (resolve, reject) =>
    if !@connected
      return reject(new FtpConnectionError("client not currently connected"))
    @client.once 'close', (hadError) ->
      resolve(hadError)
    @client.end()

  destroy: () ->
    if !@connected
      return false
    @client.destroy()
    return true


module.exports = PromiseFtp
