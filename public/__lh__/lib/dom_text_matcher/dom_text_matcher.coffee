class window.DomTextMatcher

  # ===== Public methods =======

  # Consider only the sub-tree beginning with the given node.
  # 
  # This will be the root node to use for all operations.
  setRootNode: (rootNode) -> @mapper.setRootNode rootNode

  # Consider only the sub-tree beginning with the node whose ID was given.
  # 
  # This will be the root node to use for all operations.
  setRootId: (rootId) -> @mapper.setRootId rootId

  # Use this iframe for operations.
  #
  # Call this when mapping content in an iframe.
  setRootIframe: (iframeId) -> @mapper.setRootIframe iframeId
        
  # Work with the whole DOM tree
  # 
  # (This is the default; you only need to call this, if you have configured
  # a different root earlier, and now you want to restore the default setting.)
  setRealRoot: -> @mapper.setRealRoot()

  # The available paths which can be searched
  # 
  # An array is returned, with each entry containing a "path" and a "length" field.
  # The value of the "path" field is the valid path value, "length" contains information
  # about the length of content belonging to the given path.
  getAllPaths: -> @mapper.getAllPaths()

  # Prepare for searching the specified path
  # 
  # Returns the time (in ms) it took the scan the specified path
  prepareSearch: (path, rescan = false) ->
    t0 = @timestamp()    
    @mapper.scan path, rescan
    t1 = @timestamp()
    t1 - t0

  # Search for text using exact string matching
  #
  # Parameters:
  #  pattern: what to search for
  #
  #  distinct: forbid overlapping matches? (defaults to true)
  #
  #  caseSensitive: should the search be case sensitive? (defaults to false)
  # 
  #  path: the sub-tree inside the DOM you want to search.
  #    Must be an XPath expression, relative to the configured root node.
  #    You can check for valid input values using the getAllPaths method above.
  #    It's not necessary to submit path, if the search was prepared beforehand,
  #    with the prepareSearch() method
  # 
  #  rescan: should the DOM be re-scanned, even if we already have a mapping for it?
  # 
  # For the details about the returned data structure, see the documentation of the search() method.
  searchExact: (pattern, distinct = true, caseSensitive = false, path = null, rescan = false) ->
    if not @pm then @pm = new window.DTM_ExactMatcher
    @pm.setDistinct(distinct)
    @pm.setCaseSensitive(caseSensitive)
    @search(@pm, pattern, null, path, rescan)

  # Search for text using regular expressions
  #
  # Parameters:
  #  pattern: what to search for
  #
  #  caseSensitive: should the search be case sensitive? (defaults to false)
  # 
  #  path: the sub-tree inside the DOM you want to search.
  #    Must be an XPath expression, relative to the configured root node.
  #    You can check for valid input values using the getAllPaths method above.
  #    It's not necessary to submit path, if the search was prepared beforehand,
  #    with the prepareSearch() method
  # 
  #  rescan: should the DOM be re-scanned, even if we already have a mapping for it?
  # 
  # For the details about the returned data structure, see the documentation of the search() method.
  searchRegex: (pattern, caseSensitive = false, path = null, rescan = false) ->
    if not @rm then @rm = new window.DTM_RegexMatcher
    @rm.setCaseSensitive(caseSensitive)
    @search(@rm, pattern, null, path, rescan)

  # Search for text using fuzzy text matching
  #
  # Parameters:
  #  pattern: what to search for
  #
  #  pos: where to start searching
  #
  #  caseSensitive: should the search be case sensitive? (defaults to false)
  # 
  #  matchDistance and
  #  matchThreshold:
  #     fine-tuning parameters for the d-m-p library.
  #     See http://code.google.com/p/google-diff-match-patch/wiki/API for details.
  # 
  #  path: the sub-tree inside the DOM you want to search.
  #    Must be an XPath expression, relative to the configured root node.
  #    You can check for valid input values using the getAllPaths method above.
  #    It's not necessary to submit path, if the search was prepared beforehand,
  #    with the prepareSearch() method
  # 
  #  rescan: should the DOM be re-scanned, even if we already have a mapping for it?
  # 
  # For the details about the returned data structure, see the documentation of the search() method.
  searchFuzzy: (pattern, pos, caseSensitive = false, matchDistance = 1000, matchThreshold = 0.5, path = null, rescan = false) ->
    if not @dmp? then @dmp = new window.DTM_DMPMatcher
    @dmp.setMatchDistance matchDistance
    @dmp.setMatchThreshold matchThreshold
    @dmp.setCaseSensitive caseSensitive
    @search(@dmp, pattern, pos, path, rescan)

  # ===== Private methods (never call from outside the module) =======

  constructor: (domTextMapper) ->
    @mapper = domTextMapper

  # Search for text with a custom matcher object
  #
  # Parameters:
  #  matcher: the object to use for doing the plain-text part of the search
  #  path: the sub-tree inside the DOM you want to search.
  #    Must be an XPath expression, relative to the configured root node.
  #    You can check for valid input values using the getAllPaths method above.
  #  pattern: what to search for
  #  pos: where do we expect to find it
  #
  # A list of matches is returned.
  # 
  # , each element with "start", "end", "found" and "nodes" fields.
  # start and end specify where the pattern was found; "found" is the matching slice.
  # Nodes is the list of matching nodes, with details about the matches.
  # 
  # If no match is found, null is returned.  # 
  search: (matcher, pattern, pos, path = null, rescan = false) ->
    # Prepare and check the pattern 
    unless pattern? then throw new Error "Can't search for null pattern!"
    pattern = pattern.trim()
    unless pattern? then throw new Error "Can't search an for empty pattern!"

    # Do some preparation, if required
    t0 = @timestamp()# 
    if path? then @prepareSearch(path, rescan)
    t1 = @timestamp()

    # Check preparations    
    unless @mapper.corpus? then throw new Error "Not prepared to search! (call PrepareSearch, or pass me a path)"

    # Do the text search
    textMatches = matcher.search @mapper.corpus, pattern, pos
    t2 = @timestamp()

    # Collect the mappings

    # Should work like a comprehension, but  it does not. WIll fix later.
    # matches = ($.extend {}, match, @mapper.getMappingsFor match.start, match.end) for match in textMatches

    matches = []
    for match in textMatches
      do (match) =>
        matches.push $.extend {}, match, @analyzeMatch(pattern, match), @mapper.getMappingsFor(match.start, match.end)
    t3 = @timestamp()
    return {
      matches: matches
      time:
        phase0_domMapping: t1 - t0
        phase1_textMatching: t2 - t1
        phase2_matchMapping: t3 - t2
        total: t3 - t0
    }

  timestamp: -> new Date().getTime()

  analyzeMatch: (pattern, match) ->
    found = @mapper.corpus.substr match.start, match.end-match.start
    return {
      found: found
      exact: found is pattern
    }
