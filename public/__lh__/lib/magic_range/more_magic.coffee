$.fn.xpath = (relativeRoot) ->
  jq = this.map ->
    path = ''
    elem = this

    # elementNode nodeType == 1
    while elem and elem.nodeType == 1 and elem isnt relativeRoot
      idx = $(elem.parentNode).children(elem.tagName).index(elem) + 1
      idx  = "[#{idx}]"
      path = "/" + elem.tagName.toLowerCase() + idx + path
      elem = elem.parentNode
    path
  jq.get()

$.fn.textNodes = ->
  getTextNodes = (node) ->
    # textNode nodeType == 3
    if node and node.nodeType != 3
      nodes = []
      # If not a comment then traverse children collecting text nodes.
      # We traverse the child nodes manually rather than using the .childNodes
      # property because IE9 does not update the .childNodes property after
      # .splitText() is called on a child text node.
      if node.nodeType != 8
        # Start at the last child and walk backwards through siblings.
        node = node.lastChild
        while node
          nodes.push getTextNodes(node)
          node = node.previousSibling
  
        # Finally reverse the array so that nodes are in the correct order.
      return nodes.reverse()
    else
      return node

   this.map -> $.flatten(getTextNodes(this))

$.flatten = (array) ->
  flatten = (ary) ->
    flat = []
    for el in ary
      flat = flat.concat(if el and $.isArray(el) then flatten(el) else el)
    return flat
  flatten(array)
