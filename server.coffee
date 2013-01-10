express = require 'express'
http = require 'http'
path = require 'path'
httpProxy = require 'http-proxy'
url = require 'url'

class AnnoStorage

  SID = "beaker.session.id"
  BADPW = 'Invalid username or password.'
  INTERR = "internal error"

  constructor: ->

  login: (hHost, hPort, userName, passWord, cb, cookies=null) ->
        
    data = "__formid__=login&username=" + userName + "&password=" + passWord

    options =
      hostname: hHost
      port: hPort
      path: "/app/"
      method: "POST"
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': data.length

    if cookies?
      xsrf = cookies["XSRF-TOKEN"]
      options.headers["X-XSRF-TOKEN"] = xsrf
      options.headers["Cookie"] = SID + "=" + cookies[SID] + "; XSRF-TOKEN=" + xsrf
   
#    console.log "Sending request: "
#    console.log options
#    console.log data

    req = http.request options, (res) =>
#      console.log "Status: " + res.statusCode
#      console.log "Headers"
#      console.log res.headers
      res.on 'data', (chunk) =>
        try
          result = JSON.parse chunk
        catch error
          console.log "Server responded with invalid JSON. We have sent this: "
          console.log options
          console.log "Got this:"
          console.log chunk
          cb status: INTERR
        if result? then switch result.status
          when "okay"
#            console.log "SUCCESS!!!"
#            console.log result
            cb {status: "success", token: result.model.token}
          when "failure"
            if result.error?.csrf_token?
#              console.log "OK, we need fix CSRF..."
              cookies = {}
              for c in res.headers["set-cookie"]
                ps1 = c.split "="
                cookies[ps1[0]] = (ps1[1].split ";")[0]
#              console.log cookies
              @login hHost, hPort, userName, passWord, cb, cookies
            else if result.reason is BADPW
#              console.log "Password is wrong."
              cb status: "bad password"
            else
              console.log "Unknown error: "
              console.log result
              cb status: INTERR
          else
            console.log "Unknown status: "
            console.log result
            cb status: INTERR

#        console.log d
#        if chunk is E1
           
#        console.log 'BODY: ' + chunk
#      console.log "Skipping body: " + chunk.length + " chars."

    req.on 'error', (e) ->
      console.log 'problem with request: ' + e.message
      console.log e
      cb status: "connection error"
    req.write data
    req.end()
        
 
# Settings
MAIN_PORT = 8000
LH_PREFIX = "__lh__"
LH_PATH = "/" + LH_PREFIX
SESSION_TIME = 3600 * 1000

timestamp = -> new Date().getTime()

parseLocation = (urlString) ->
  u = url.parse urlString
  [u.hostname, u.port ? 80, u.path + (u.hash ? "")]

# Set up app
# 
app = express()
proxy = new httpProxy.RoutingProxy()
storage = new AnnoStorage()

app.configure ->
  app.set 'port', MAIN_PORT
  app.use express.favicon()
  app.use express.logger 'dev'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser LH_PREFIX + " magic secret key"
  app.use express.cookieSession "Loud.Howard.Session.x"
  app.use app.router
  app.use express.static path.join __dirname, 'public'

app.configure 'development', -> app.use express.errorHandler()

app.get LH_PATH + '/loading', (req, res) -> res.send "Loading..."

app.get LH_PATH + "/login_status", (req, res) -> res.send
  host: req.session.hHost ? "none"
  port: req.session.hPort ? "none"
  user: req.session.hUser ? "none"
  token: req.session.hToken ? "none"

app.post LH_PATH + '/login', (req, res) ->
  console.log "Should login:"
  console.log req.body
  storage.login req.body.host, req.body.port, req.body.user, req.body.pass, (result) ->
    console.log "Login result: "
    console.log result
    if result.status is "success"
      req.session.hHost = req.body.host
      req.session.hPort = req.body.port
      req.session.hUser = req.body.user
      req.session.hToken = result.token
    res.send result

app.post LH_PATH + '/logout', (req, res) ->
  delete req.session.hHost
  delete req.session.hPort
  delete req.session.hUser
  delete req.session.hToken
  res.send "OK"
        
app.get LH_PATH + '/redirect', (req, res) ->
  console.log "Arrived to redirector."
  if req.session.redirectLocation?
    console.log "Fwding to " + req.session.redirectLocation
    res.redirect req.session.redirectLocation
    delete req.session.redirectLocation
  else
    console.log "Ooops. No redirect expected. Sending to start"
    res.send "No redirect expected. What are you doing here?"

app.get LH_PATH + '/setup_proxy/:host/:port', (req, res) ->
  req.session.proxyHost = req.params.host
  req.session.proxyPort = req.params.port
  req.session.timestamp = timestamp()
  delete req.session.redirectLocation
  delete req.session.redirectedTo
  res.send
    status: "success"

app.get LH_PATH + '/forget_proxy', (req, res) ->
  delete req.session.proxyHost
  delete req.session.proxyPort
  res.send "OK"

app.get LH_PATH + '/get_redirection', (req, res) -> res.send req.session.redirectedTo

app.all '/*', (req, res, next) ->
  pf = req.url.substr 0, LH_PATH.length
  if pf is LH_PATH
    next()
  else
    unless (req.session?.proxyHost? and req.session.timestamp? and timestamp() - req.session.timestamp <= SESSION_TIME)
      res.redirect LH_PATH
    else
#      req.session = null
#      res.send "hohoho"
#      return

      console.log "Incoming proxy request for " + req.session.proxyHost + ":" + req.session.proxyPort + req.url

      # set fake hostname
      req.headers.host = req.session.proxyHost
      if req.session.proxyPort isnt "80" then req.headers.host += ":" + req.session.proxyPort

      #hijack HTTP headers
      res.oldWriteHead = res.writeHead
      res.writeHead = (statusCode, headers) ->
         if req.session.inRedirect
           delete req.session.inRedirect                
           console.log "Redirection writing head.."
           res.oldWriteHead statusCode, headers
           return
        
#         console.log "In writeHead. Headers are:"
#         console.log headers
                
         if headers["x-frame-options"]?
           console.log "Site tried to set x-frame-options eating it for good."
           delete headers["x-frame-options"]
        
         if headers["location"]?
           req.session.redirectedTo = newLocation = headers["location"]
           req.session.inRedirect = true
           req.session.timestamp = timestamp()
           [req.session.proxyHost, req.session.proxyPort, req.session.redirectLocation] = parseLocation newLocation
           console.log "Redirection detected to '" + newLocation + "'. Going to /redirect first."
           res.redirect LH_PATH + "/redirect"
         else 
           delete headers["Cache-Control"]
           headers["cache-control"] = "no-cache"
           res.oldWriteHead statusCode, headers
        
      unless res.redirected? then proxy.proxyRequest req, res, { host: req.session.proxyHost, port: req.session.proxyPort }

app.listen MAIN_PORT
console.log "Server listens on port " + MAIN_PORT

