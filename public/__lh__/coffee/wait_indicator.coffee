# This angular module provides a service and a matching directive
# to display modal dialogs to indicate a running process.

class WaitIndicatorService
  constructor: ($rootScope) ->
    @rootScope = $rootScope

  timestamp: -> new Date().getTime()

  set: (title, desc) ->
    @rootScope.waitIndicatorTitle = title
    @rootScope.waitIndicatorText = desc
    @lastUpdated = @timestamp()
    $('#wait-indicator-dialog').modal 'show'

  # Is the time passed since the message was last updated
  # longer than the given number of miliseconds?
  olderThan: (timeLimit) ->
    @timestamp() - @lastUpdated > timeLimit

  finished: ->
    $('#wait-indicator-dialog').modal 'hide'        

angular.module('waitIndicator', [])
  .service('waitIndicator', ['$rootScope', WaitIndicatorService])
#  .directive 'waitIndicator', -> (scope, elm, attrs) -> elm.text(version)

