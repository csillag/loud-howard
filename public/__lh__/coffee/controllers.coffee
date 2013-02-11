#Controllers

class GenController

  AUTO_LOGIN = true
  AUTO_URL = true
  AUTO_LOAD_ON_LOGIN = true
  AUTO_ANNOTATE = false
  AUTO_SAVE = false

  BORDER_CHARS = " ,.!?+-/*()$%&;:"
  LH_PREFIX = "__lh__"
  LH_PATH = "/" + LH_PREFIX
  PATH_PREFIX_LENGTH = "/html[1]/body[1]".length
  SAVE_WAIT_SECS = 1
  MAX_QUOTE_LENGTH = 64
       
  this.$inject = ['$scope', '$http', '$timeout', '$document', 'domTextMapper', 'domTextHiliter', 'waitIndicator']
  constructor: ($scope, $http, $timeout, $document, domTextMapper, domTextHiliter, waitIndicator) ->

    $http.get(LH_PATH + "/forget_proxy")#.success (data) => console.log "Reseted proxy"

    window.wtfscope = $scope
        
    $scope.init = ->
      @domMapper = domTextMapper.getInstance()   

      @loadSettings = false
      @documentExplanation = "Loading of this document started with the specified URL, but we are not detecting whether it was redirected somewhere else. So the loaded document might not correspond to the specified URL."

      @$watch 'selectedPath', => @prepareSelectedPath()
      @wait = waitIndicator
      @hiliter = domTextHiliter
      @candidateMinLength = 500
      @numAnnotations = 10
      @distribution = "uniform"
      @minLength=3
      @maxLength=50
      @selectWholeWords = true
      @annotationBodyText = "AUTO-GENERATED TEST ANNOTATION"
      @devMode = document.location.hostname is "localhost"
      @targetServer = "hypotest"
      if @devMode and AUTO_URL then @wantedURL = "http://en.wikipedia.org/wiki/Criteria_of_truth"

    $scope.init()

    # Get a shortened version of any text
    $scope.getExcerpt = (text, length = MAX_QUOTE_LENGTH) ->
      exLen = length / 2
      if text.length <= length
        text
      else
        (text.substr 0, exLen) + " [...] " + (text.substr text.length-exLen)

    $scope.splitURL = (url) ->
      a = document.createElement 'a'
      a.href = @wantedURL
#      console.log a
      protocol = a.protocol
      host = a.hostname #encodeURIComponent a.hostname
      port = if a.port is "" then "80" else a.port
      path = a.pathname # encodeURIComponent a.pathname
      search = a.search # encodeURIComponent a.search
      hash = a.hash # encodeURIComponent a.hash

#      console.log "Protocol: " + protocol
#      console.log "Host: " + host
#      console.log "Port: " + port
#      console.log "Path: " + path
#      console.log "Search: " + search
#      console.log "Hash: " + hash

      [host, port, path + search + hash]

    $scope.loadWithProxy = ->
      [host, port, path] = @splitURL @wantedURL
      $http.get(LH_PATH + "/setup_proxy/" + host + "/" + port).success (data) =>
        if data.status is "success"
          @shouldLoad = path
          @sourceURL = LH_PATH + "/loading" # path
#          console.log "Proxy configured; should load " + @sourceURL
        else
          alert "Failed to configure proxy: " + data.message        

    $scope.urlEdited = ->
      if not @wantedURL?
        alert "Please enter a valid URL!"
        return  

      delete @paths
      delete @offeredPaths
      delete @selectedPath
   
      console.log "Wanted URL is: " + @wantedURL

      @wait.set "Loading…", "Please wait while the specified document is loaded!"

      $timeout => @loadWithProxy()

    $scope.getIframe = -> window.document.getElementById "loud-howard-article-box"

    $scope.loadedOK = -> 
      content = @getIframe().contentDocument.documentElement.innerHTML
      content isnt '<head></head><body></body>'

    $scope.getLoadedPath = ->
      loc = @getIframe().contentDocument.location
      loc.pathname + loc.search + loc.hash

    $scope.fixSize = =>
      top = $(".navbar").outerHeight() + 5
      $("#article-container").css("top", top + "px")
      $timeout (=> $scope.fixSize()), 1000

    $scope.fixSize()

    window.loudHowardUrlLoaded = =>
      $scope.$apply =>
        if $scope.shouldLoad?
#          console.log "Pre-loading ready. Now starting real load..."
          $scope.sourceURL = $scope.shouldLoad
          delete $scope.shouldLoad
          return
        
        console.log "URL loaded."
        $http.get(LH_PATH + "/get_redirection").success (data) =>
          if data isnt ""
            console.log "Was server-redirected to " + data
            $scope.wantedURL = data
          [host, port, wantedPath] = $scope.splitURL @wantedURL
          actualPath = $scope.getLoadedPath()
          if actualPath isnt wantedPath
            $scope.wantedURL = "http://" + host + (if port isnt "80" then ":" + port else "") + actualPath

        if $scope.loadedOK()
          $scope.wait.set "Parsing…", "Please wait while the document is being analyzed!"
          $scope.domMapper.setRootIframe "loud-howard-article-box"
          $scope.domMapper.documentChanged()        
          delete $scope.paths
          delete $scope.selectedPath
          delete $scope.selectedPathData
          $scope.checkPaths()
        else
          $scope.wait.finished()
          alert "Failed to load document. Sorry. Probably has something to do with cookies vs proxying."

    $scope.checkPaths = ->
      # wait for the browser to render the DOM for the new HTML
      $timeout =>
        @paths ?= @domMapper.getAllPaths()
        @domMapper.scan()
        @filterPathCandidates()
        if @selectedPath in @offeredPaths
          @prepareSelectedPath()
        else
          @selectedPath = @domMapper.getDefaultPath() 

    $scope.filterPathCandidates = ->
      @offeredPaths = for path, data of @paths when data.length >= @candidateMinLength then path
      if @offeredPaths.length is 0
        @candidateMinLength = Math.max (data.length for path, data of @paths)...
        @filterPathCandidates()

    $scope.getSummary = (path) ->
      i = @paths[path]  
      exc = @getExcerpt i.content
      sum = path + " ('" + exc + "'; " + i.length + " chars)"
        
    $scope.prepareSelectedPath = ->
      unless @selectedPath? then return
      console.log "Chosen " + @selectedPath + "."
      @hiliter.undo @task
      delete @annotations
      delete @anchors        
      @selectedPathData = @paths[@selectedPath]
      if @selectedPath isnt "/HTML/BODY" then @domMapper.selectPath @selectedPath, true
      @wait.finished()
      if @devMode and AUTO_ANNOTATE then @generateAnnotations()

    $scope.getRandomInt = (min, max) -> min + Math.floor (Math.random() * (max - min + 1))

    $scope.makeUniformDistribution = ->
      lengths = {}
      for x in [1..@numAnnotations]
        l = @getRandomInt @minLength, @maxLength
        lengths[l] ?= 0
        lengths[l] += 1
      lengths

    $scope.getLengthDistribution = ->
      switch @distribution
        when "uniform" then @makeUniformDistribution()
        when "gauss" then @makeGaussDistribution()
        when "boltzmann" then @makeBoltzmannDistribution()
        else alert "Unknown distribution requested: '" + @distribution + "'."
        
    $scope.getLengths = (numLength) ->
      results = []
      for k, v of @getLengthDistribution()
        for i in [1..v]
          results.push parseInt k
      results

     $scope.generateAnnotations = ->
      @hiliter.undo @task
      cont = @selectedPathData.content
      maxLen = @selectedPathData.length
      range = @domMapper.getRangeForPath @selectedPath
      offset = range.start

      @anchors = (len:l, start:@getRandomInt 0, maxLen - l for l in @getLengths())


      for anchor in @anchors
        anchor.end = anchor.start + anchor.len        
        if @selectWholeWords
          while anchor.start and (BORDER_CHARS.indexOf cont[anchor.start - 1]) is -1
            anchor.start -= 1
          while anchor.end < maxLen and (BORDER_CHARS.indexOf cont[anchor.end]) is -1
            anchor.end += 1
          anchor.len = anchor.end - anchor.start
        anchor.text = cont.substr anchor.start, anchor.len
        console.log "Anchor text: '" + anchor.text + "'"
        anchor.startGlobal = anchor.start + offset
        anchor.endGlobal = anchor.end + offset
        anchor.mappings = @domMapper.getMappingsForRange anchor.startGlobal, anchor.endGlobal
        anchor.magicRange = @getMagicRange anchor.mappings
#        console.log "Now should restore DOM & data cache integrity..."
        @domMapper.documentChanged()
        @paths = @domMapper.getAllPaths()
        @domMapper.scan()
#        console.log "Data updated."        
#        console.log anchor.mappings

      console.log "Now re-calculating native mapping info for updated DOM structure..."
      for anchor in @anchors
        anchor.mappings = @domMapper.getMappingsForRange anchor.startGlobal, anchor.endGlobal
      console.log "Done."        
        
      console.log "Generated anchors."
      console.log @anchors

      @task = ranges: (nodes: anchor.mappings.nodes for anchor in @anchors)
      @hiliter.highlight @task

      @annotations = (@createAnnotation anchor for anchor in @anchors)
      console.log "Generated annotations."
      console.log @annotations

      if @devMode and AUTO_SAVE then @saveAnnotations()

    $scope.getMagicRange = (mapping) ->
#      console.log "Creating magic range for this mapping: "
#      console.log mapping
      range = mapping.range
#      console.log if range.startContainer is range.endContainer then "Simple-element range" else "Multi-element range"
#      console.log range.startOffset + " - " + range.endOffset
      browserRange = new magic.Range.BrowserRange range
      magicRange = browserRange.serialize()
#      console.log "Magic is: "
#      console.log magicRange
      magicRange

    $scope.transformForStorage = (r) ->
      result =
        end: r.end.substr PATH_PREFIX_LENGTH
        start: r.start.substr PATH_PREFIX_LENGTH
        startOffset: r.startOffset
        endOffset: r.endOffset

    $scope.createAnnotation = (anchor) ->
      ts = (new Date()).toString()
      {
        updated: ts
        created: ts
        quote: anchor.text
        uri: @wantedURL
        ranges: [
          @transformForStorage anchor.magicRange
        ]
#        ranges: [
#          start: @transformPath anchor.mappings.rangeInfo.startPath
#          end: @transformPath anchor.mappings.rangeInfo.endPath
#          startOffset: anchor.mappings.rangeInfo.startOffset
#          endOffset: anchor.mappings.rangeInfo.endOffset
#        ]
        user: "acct:" + @serverUser + "@" + @serverHost + ":" + @serverPort
        text: @annotationBodyText
        permissions:
          read: []
          admin: []
          update: []
          delete: []
      }

    $scope.getLoginStatus = ->
      console.log "Checking login status..."
      $http.get(LH_PATH + "/login_status").success (result) =>
        @serverHost = result.host
        @serverPort = result.port
        @serverUser = result.user
        [@persona, @token] = if @serverHost isnt "none"
          [@serverUser + "/" + @serverHost + ":" + @serverPort, result.token]
        else
          [null, null]
        if @persona? and @devMode and AUTO_LOAD_ON_LOGIN then $scope.urlEdited()

    $scope.logout = ->
      $http.post(LH_PATH + "/logout").success => @getLoginStatus()
      @hiliter.undo @task
      delete @annotations
      delete @anchors
      delete @paths
      delete @sourceURL
        
    $scope.login = (hHost, hPort, userName, passWord) ->
      loginData =
        host: hHost
        port: hPort
        user: userName
        pass: passWord
        
      $http.post(LH_PATH + "/login", loginData).success (result) =>
        switch result.status
          when "connection error" then alert "Can not connect to server."
          when "bad password" then alert "Invalid username or password."
          when "internal error" then alert "Could not log you in due to an internal error. Sorry."
          when "success"
             console.log "Login succeeded."
             @getLoginStatus()
          else alert "Could not unterstand the server's answer. Sorry"

    $scope.tryLogin = ->
      console.log "Logging in to " + @targetServer
      [host, port] = switch @targetServer
        when "localhost" then ["localhost", 5000]
        when "hypotest" then ["hypotest.nolmecolindor.com", 8000]
        when "dev" then ["dev.hypothes.is", 80]
        when "test" then ["test.hypothes.is", 80]
        else [null, null]
      if host?
        @login host, port, @loginUser, @loginPass
      else
        console.log "Unknown target server " + @targetServer

    $scope.annotationSaved = ->
      @pendingSaveCount -= 1
      @wait.set "Saving…", "Please wait while saving the annotations! (" + @pendingSaveCount + " more to go.)"
      if @pendingSaveCount is 0
        @wait.finished()
        @hiliter.undo @task
        delete @annotations
        delete @anchors

    $scope.saveAnnotation = (annotation) ->
      console.log "Sending save request..."
      url = "http://" + @serverHost + ":" + @serverPort + "/api/current/annotations"
      $http.post(url, annotation)
        .success (data, status, headers, config) =>
          console.log data
          @annotationSaved()
        .error (data, status, headers, config) =>
           console.log "Error!"
           switch status
             when 0 then alert "Could not connect to server!"
             when 401
               console.log data        
               alert "Access denied. That means an authentication problem with the server..."
             else
               console.log "Unknown error while saving annotation:"
               console.log data
               console.log status
               console.log headers
               console.log config
           @annotationSaved()                
        
    $scope.saveAnnotations = ->
      @wait.set "Saving…", "Please wait while saving the annotations!"
      console.log "Saving annotations to " + @serverHost
#      console.log @annotations
      @pendingSaveCount = @annotations.length
      $http.defaults.headers.post["x-annotator-auth-token"] = @token

      for i in [0 ... @annotations.length]
        do (i) ->
          $timeout (=> $scope.saveAnnotation $scope.annotations[i]), i * SAVE_WAIT_SECS * 1000

    $scope.getLoginStatus()

    if @devMode and AUTO_LOGIN
       $scope.loginUser = "LoudHoward2"
       $scope.loginPass = "lemmeshout"



#      $scope.login "localhost", 5000, "LoudHoward2", "lemmeshout"
#      $scope.login "hypotest", 8000, "LoudHoward2", "lemmeshout", (res) ->

angular.module('loudHoward.controllers', [])
  .controller("GenController", GenController)
