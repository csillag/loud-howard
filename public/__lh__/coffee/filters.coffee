
# Filters

angular
  .module('loudHoward.filters', [])
  .filter('interpolate', 
    ['version', (version)->
      (text)->
        return String(text).replace(/\%VERSION\%/mg, version)
    ])