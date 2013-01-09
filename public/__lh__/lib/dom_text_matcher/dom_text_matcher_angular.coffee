angular.module 'domTextMatcher', [], ($provide) ->
  $provide.factory "domTextMapper", -> getInstance: -> new DomTextMapper
  $provide.factory "domTextHiliter", -> getInstance: -> new DomTextHiliter
#  $provide.factory "domTextMatcher", ["domTextMapper", (domTextMapper) ->
#    getInstance: -> new DomTextMatcher domTextMapper.getInstance()
#  ]
