angular.module 'domTextMapper', [], ($provide) ->
  $provide.factory "domTextMapper", -> getInstance: -> new DomTextMapper
