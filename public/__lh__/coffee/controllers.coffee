#Controllers

class GenController

  AUTO_MODE = true

  BORDER_CHARS = " ,.!?+-/*()$%&;:"
  LH_PREFIX = "__lh__"
  LH_PATH = "/" + LH_PREFIX
  PATH_PREFIX_LENGTH = "/html/body".length
        
  this.$inject = ['$scope', '$http', '$timeout', '$document', 'domTextMapper', 'domTextHiliter', 'waitIndicator']
  constructor: ($scope, $http, $timeout, $document, domTextMapper, domTextHiliter, waitIndicator) ->

    $http.get(LH_PATH + "/forget_proxy").success (data) =>
      console.log "Reseted proxy"

    $document.find("#help1").popover(html:true)

    window.wtfscope = $scope
        
    $scope.init = ->
      @domMapper = domTextMapper.getInstance()   
#      @wantedURL = "http://www.google.com"
#      @wantedURL = "http://google.hu"
#      @wantedURL = "http://index.hu/belfold/2013/01/04/egymast_martjak_be_a_birosagi_vegrehajtok/"
#      @wantedURL = "http://index.hu/belfold"

      if AUTO_MODE then @wantedURL = "http://en.wikipedia.org/wiki/Breast"
#      @wantedURL = "http://en.wikipedia.org/wiki/Truth"

      @loadSettings = false
      @documentExplanation = "Loading of this document started with the specified URL, but we are not detecting whether it was redirected somewhere else. So the loaded document might not correspond to the specified URL."

      @$watch 'selectedPath', => @prepareSelectedPath()
      @wait = waitIndicator
      @hiliter = domTextHiliter.getInstance()
      @candidateMinLength = 500
      @numAnnotations = 10
      @distribution = "uniform"
      @minLength=3
      @maxLength=50
      @selectWholeWords = true
      @annotationUser = "LoudHoward"
      @annotationBodyText = "AUTO-GENERATED TEST ANNOTATION"
      @devMode = document.location.hostname is "localhost"
      @targetServer = if @devMode then "localhost" else "dev"

    $scope.init()

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
          console.log "Proxy configured; should load " + @sourceURL
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
          console.log "Pre-loading ready. Now starting real load..."
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
          delete $scope.paths
          delete $scope.selectedPath
          delete $scope.selectedPathData
          $scope.domMapper.setRootIframe "loud-howard-article-box"
          $scope.domMapper.scan null, true
          $scope.checkPaths()
        else
          $scope.wait.finished()
          alert "Failed to load document. Sorry. Probably has something to do with cookies vs proxying."

    $scope.checkPaths = ->
      # wait for the browser to render the DOM for the new HTML
      $timeout =>
        @paths ?= @domMapper.getAllPaths()
        @filterPathCandidates()

        if @selectedPath in @offeredPaths
          @prepareSelectedPath()
        else
          @selectedPath = @offeredPaths[0]

    $scope.filterPathCandidates = ->
      @offeredPaths = for path, data of @paths when data.length >= @candidateMinLength then path
      if @offeredPaths.length is 0
        @candidateMinLength = Math.max (data.length for path, data of @paths)...
        @filterPathCandidates()
  
    $scope.prepareSelectedPath = ->
      if @task then @hiliter.undo @task  
      unless @selectedPath? then return
      @selectedPathData = @paths[@selectedPath]
      @selectedPathExcerpt = @domMapper.getExcerpt @selectedPathData.content, 400
      if @selectedPath isnt "/HTML/BODY" then @domMapper.selectPath @selectedPath
      @selectedPathData.node.scrollIntoViewIfNeeded()
      console.log "Chosen " + @selectedPath + "."
      @wait.finished()
      if @task? then @hiliter.undo @task
      delete @annotations
      if AUTO_MODE then @generateAnnotations()

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
      if @task? then @hiliter.undo @task
      cont = @selectedPathData.mapping.content
      maxLen = @selectedPathData.length
      offset = @selectedPathData.mapping.start
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
#        console.log "Anchor text: '" + anchor.text + "'"
        anchor.startGlobal = anchor.start + offset
        anchor.endGlobal = anchor.end + offset
        anchor.mappings = @domMapper.getMappingsFor anchor.startGlobal, anchor.endGlobal

      @task = ranges: (nodes: anchor.mappings.nodes for anchor in @anchors)
      @hiliter.highlight @task

      @annotations = (@createAnnotation anchor for anchor in @anchors)
      if AUTO_MODE then @saveAnnotations()

    $scope.createAnnotation = (anchor) ->
      ts = (new Date()).toString()
      {
        updated: ts
        created: ts
        qoute: anchor.text
        uri: @wantedURL
        ranges: [
          start: anchor.mappings.rangeInfo.startPath.substr PATH_PREFIX_LENGTH
          end: anchor.mappings.rangeInfo.endPath.substr PATH_PREFIX_LENGTH
          startOffset: anchor.mappings.rangeInfo.startOffset
          endOffset: anchor.mappings.rangeInfo.endOffset
        ]
        user: "acct:" + @annotationUser + "@" + "0.0.0.0:5000"
        text: @annotationBodyText
        permissions:
          read: []
          admin: []
          update: []
          delete: []
      }

    $scope.login = (hHost, hPort, userName, passWord) ->
      url1 = "http://" + hHost + ":" + hPort + "/app/?xdm_e=http%3A%2F%2F" + hHost + "t%3A" + hPort + "%2F&xdm_c=annotator&xdm_p=4"

      xsrf = $.param
        username: userName
        password: passWord
        __formid__: "login"

      console.log xsrf
      return
        
      call = $http
        method: 'POST'
        url: url1
        data: xsrf
        headers: {'Content-Type': 'application/x-www-form-urlencoded'}


      call.success (data) ->
        console.log data
      call.error (data) ->
        console.log data  


        
#      console.log tokenURL = "http://" + host + "/app/token"
#      $http.get(tokenURL).success (data) ->
#        console.log "Got token: " + data
        
      return
      p =
        username: userName
        provider: provider
      data =
        flash: {}
        status: "okay"
        model:
          persona: p
          personas: [p]
          token: token
          tokenURL: tokenURL

    $scope.saveAnnotations = ->
      console.log "Should save annotatinos to " + @targetServer
      console.log @annotations
      token = "fake-token"
      $http.defaults.headers.post["x-annotator-auth-token"] = token
      console.log "Default headers: "
      console.log $http.defaults.headers.common
      console.log "Post headers: "
      console.log $http.defaults.headers.post
#      return
#"x-xsrf-token"
      url = "http://0.0.0.0:5000/api/current/annotations"
      $http.post(url, @annotations[0])
        .success (data, status, headers, config) ->
           console.log "Success!"
        .error (data, status, headers, config) ->
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

    if AUTO_MODE
#      $scope.urlEdited()
      $scope.login "localhost", 5000, "LoudHoward2", "lemmeshout"

angular.module('loudHoward.controllers', [])
  .controller("GenController", GenController)
