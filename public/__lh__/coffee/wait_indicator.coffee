# This angular module provides a service and a matching directive
# to display modal dialogs to indicate a running process.

class WaitIndicatorService
  constructor: ($rootScope) ->
    @rootScope = $rootScope

  set: (title, desc) ->
    @rootScope.waitIndicatorTitle = title
    @rootScope.waitIndicatorText = desc
    $('#wait-indicator-dialog').modal 'show'

  finished: ->
    $('#wait-indicator-dialog').modal 'hide'        

angular.module('waitIndicator', [])
  .service('waitIndicator', ['$rootScope', WaitIndicatorService])
#  .directive 'waitIndicator', -> (scope, elm, attrs) -> elm.text(version)

