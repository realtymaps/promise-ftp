Description
===========

promise-ftp is an FTP client module for [node.js](http://nodejs.org/) that provides a promise-based interface for
communicating with an FTP server.

This module is a thin wrapper around the [node-ftp](https://github.com/mscdex/node-ftp/blob/master/README.md) module.

This library is written primarily in CoffeeScript, but may be used just as easily in a Node app using Javascript or
CoffeeScript.  Promises in this module are provided by [Bluebird](https://github.com/petkaantonov/bluebird).


Requirements
============

* [node.js](http://nodejs.org/) -- v0.8.0 or newer


Install
=======

    npm install promise-ftp


Examples
========

* Get a directory listing of the current (remote) working directory:

```javascript
  var PromiseFtp = require('promise-ftp');
  
  var ftp = new PromiseFtp();
  ftp.connect({host: host, user: user, password: password})
  .then(function (serverMessage) {
    console.log('Server message: '+serverMessage);
    return ftp.list('/');
  }).then(function (list) {
    console.log('Directory listing:');
    console.dir(list);
    return ftp.end();
  });
```

* Download remote file 'foo.txt' and save it to the local file system:

```javascript
  var PromiseFtp = require('promise-ftp');
  var fs = require('fs');
  
  var ftp = new PromiseFtp();
  ftp.connect({host: host, user: user, password: password})
  .then(function (serverMessage) {
    return ftp.get('foo.txt');
  }).then(function (stream) {
    return new Promise(function (resolve, reject) {
      stream.once('close', resolve);
      stream.once('error', reject);
      stream.pipe(fs.createWriteStream('foo.local-copy.txt'));
    });
  }).then(function () {
    return ftp.end();
  });
```

* Upload local file 'foo.txt' to the server:

```javascript
  var PromiseFtp = require('promise-ftp');
  var fs = require('fs');
  
  var ftp = new PromiseFtp();
  ftp.connect({host: host, user: user, password: password})
  .then(function (serverMessage) {
    return ftp.put('foo.txt', 'foo.remote-copy.txt');
  }).then(function () {
    return ftp.end();
  });
```


API
===

For the most part, this module's API mirrors [node-ftp's API](https://github.com/mscdex/node-ftp#api), except that it
returns promises which resolve or reject, rather than emitting events or calling callbacks.  Only differences are
described below.


Methods
-------

* **(constructor)**() - Creates and returns a new FTP client instance (not via a promise).

* **connect**(< _object_ >config) - Connects to an FTP server; returned promise resolves to the server's greeting
message. Valid config properties are identical to [node-ftp](https://github.com/mscdex/node-ftp#methods).

* **end**() - Closes the connection to the server after any/all enqueued commands have been executed; returned promise
resolves to a boolean indicating whether there was an error associated with closing the connection.

* **destroy**() - Closes the connection to the server immediately; returns a boolean rather than a promise, indicating
whether the client was connected prior to the call to `destroy()`.

* **site**(< _string_ >command) - Sends `command` (e.g. 'CHMOD 755 foo', 'QUOTA') using SITE; returned promise resolves
to an object with the following attributes:
  * _text_: < _string >responseText
  * _code_: < _integer_ >responseCode.

* **all other methods are virtually identical to those of [node-ftp](https://github.com/mscdex/node-ftp#api), except
returning results and errors via promise.*
