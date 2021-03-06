#Longer lived interactions we want here
chrome.runtime.onConnectExternal.addListener (port) ->
  switch port.name
    when "sync" then syncConnection(port)
    when "decryption" then decryptionConnection(port)

#For short requests.. use just a simple one-time request
chrome.runtime.onMessageExternal.addListener (request, sender, sendResponse) ->
  #TODO authenticate the sender??
  console.log("Recieved externalMessage")
  switch request.cmd
    when "auth"
      if AppSettings.userID
        sendResponse({cmd: 'getToken', user: AppSettings.userID, secret: AppSettings.userSecret})
      else
        AppSettings.userSecret = generateUUID()
        sendResponse({cmd: 'newClient', secret: AppSettings.userSecret})
    when "saveID" then AppSettings.userID = request.user
    when "detect" then sendResponse({autoSync: AppSettings.autoSync})
    when 'history' 
      chrome.history.search {text: request.url}, (items) ->
        sendResponse({cmd: 'found', item: items[0]})
      return true

syncConnection = (port) ->
  worker = new Worker('/js/syncer.js')
  worker.addEventListener 'message', (msg) ->
    switch msg.data.cmd
      when 'syncFailed'
        Logger.error "Sync failure #{msg.data.err}"
        AppSettings.syncProgress = {status: 'failed', err: msg.data.err, lastSuccess: AppSettings.lastSync}
        AppSettings.nextSync = Date.now() + AppSettings.retryInterval
        port.postMessage({cmd: 'failure', time: AppSettings.syncProgress.time})
        port.disconnect()
      when 'syncStatus'
        AppSettings.syncProgress = {status: 'syncing', total: msg.data.total, stored: msg.data.stored}
        AppSettings.lastSync = Date.now()
        port.postMessage(_.extend({cmd: 'update'}, AppSettings.syncProgress))
        Logger.info "Sync progress #{Math.floor((msg.data.stored / msg.data.total) * 100)} %"
      when 'syncComplete'
        Logger.info "Sync Complete"
        AppSettings.syncProgress = {status: 'complete', time: Date.now()}
        AppSettings.lastSync = Date.now()
        AppSettings.nextSync = Date.now() + AppSettings.syncInterval
        port.postMessage({cmd: 'complete', time: AppSettings.syncProgress.time})
      else
        port.postMessage(msg.data)
 
  port.onMessage.addListener (msg) ->
    switch msg.cmd
      when 'start'
        worker.postMessage({cmd: 'sync', stopPoints: msg.stopPoints, external: true})
      when 'syncErr'
        worker.terminate()
        Logger.error(err)
      else
        worker.postMessage(msg)

  port.onDisconnect.addListener () ->
    worker.terminate()

hex2a = (hex) ->
  str = ''
  i = 0
  while i < hex.length
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
    i += 2
  return str

decryptionConnection = (port) ->
  port.onMessage.addListener (msg) ->
    item = msg.payload
    err = null
    fields = []
    for field in msg.fields
      try
        if item[field] and item[field] instanceof Array
          for k,idx in item[field]
            item[field][idx] = hex2a(CryptoJS.AES.decrypt(k, AppSettings.encryptionKey).toString())
        else if item[field]
          item[field] = hex2a(CryptoJS.AES.decrypt(item[field], AppSettings.encryptionKey).toString())
        fields.push(field)
      catch err
        err = err
    if err
      port.postMessage({cmd: 'decryptionError', decrypted: item, err: err, fields: fields})
    else
      port.postMessage({cmd: 'decrypted', decrypted: item, fields: fields})
