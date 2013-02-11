#Controllers

class GenController


  PATH_PREFIX_LENGTH = "/html/body".length
  PATH_SUFFIX = "/text()"
  SAVE_WAIT_SECS = 1

       
  this.$inject = ['$scope', '$http', '$timeout', '$document', 'domTextMapper', 'domTextHiliter', 'waitIndicator']
  constructor: ($scope, $http, $timeout, $document, domTextMapper, domTextHiliter, waitIndicator) ->

        
    $scope.init = ->

      @loadSettings = false

      @wait = waitIndicator
      @hiliter = domTextHiliter.getInstance()



    $scope.transformPath = (path) ->
      path = path.substr PATH_PREFIX_LENGTH
      if path.length >= PATH_SUFFIX.length
        pathEnd = path.substr path.length - PATH_SUFFIX.length
        if pathEnd is PATH_SUFFIX
          path = path.substr 0, path.length - PATH_SUFFIX.length
      path

    $scope.createAnnotation = (anchor) ->
      ts = (new Date()).toString()
      {
        updated: ts
        created: ts
        qoute: anchor.text
        uri: @wantedURL
        ranges: [
          start: @transformPath anchor.mappings.rangeInfo.startPath
          end: @transformPath anchor.mappings.rangeInfo.endPath
          startOffset: anchor.mappings.rangeInfo.startOffset
          endOffset: anchor.mappings.rangeInfo.endOffset
        ]
        user: "acct:" + @serverUser + "@" + @serverHost + ":" + @serverPort
        text: @annotationBodyText
        permissions:
          read: []
          admin: []
          update: []
          delete: []
      }


    $scope.annotationSaved = ->
      @pendingSaveCount -= 1
      @wait.set "Saving…", "Please wait while saving the annotations! (" + @pendingSaveCount + " more to go.)"
      if @pendingSaveCount is 0
        @wait.finished()
        if @task? then @hiliter.undo @task
        delete @annotations

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
      console.log @annotations
      @pendingSaveCount = @annotations.length
      $http.defaults.headers.post["x-annotator-auth-token"] = @token
      t = 0
      for annotation in @annotations
        $timeout (=> @saveAnnotation annotation), t*1000
        t += SAVE_WAIT_SECS

    $scope.getLoginStatus()

    if @devMode and AUTO_LOGIN
       $scope.loginUser = "LoudHoward2"
       $scope.loginPass = "lemmeshout"



#      $scope.login "localhost", 5000, "LoudHoward2", "lemmeshout"
#      $scope.login "hypotest", 8000, "LoudHoward2", "lemmeshout", (res) ->

angular.module('loudHoward.controllers', [])
  .controller("GenController", GenController)
