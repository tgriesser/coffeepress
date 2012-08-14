# Coffeepress
# A simple helper to package numerous coffeescript files into 
# a single file before "coffee-scripting"
# 
# Author  - Tim Griesser
# License - MIT

_ = require('underscore')
fs = require('fs')
path = require('path')
ObjectDump = require('objectdump')

# Coffeepress constructor... initializes a new
# coffeescript template instance, where the first parameter
# is the filename of the file to be processed.  
# Grabs a noconflict of the '_' so that there isn't any issues  
# overwriting the template settings  
Coffeepress = (filename, settings = {}) ->
  
  # File name for the directory
  @filename = filename

  # Remove the filename from the path
  directory = filename.split(path.sep)
  directory.pop()
  @directory = directory.join(path.sep)

  if settings.rebuild?
    @rebuilt = true

  # Set any variables
  if settings.variables?
    @setVar(settings.variables)

  # Set any aliases
  if settings.aliases?
    @setAlias(settings.aliases)

  # Set any template settings
  if settings.templateSettings?
    @setTemplateSettings(settings.templateSettings)

  this

# Extend the Coffeepress prototype
_.extend(Coffeepress::, {

  # Experimental - trigger a rebuild of the JS file while open
  rebuild : false

  # The base file that is being processed for the coffeescript
  filename : null

  # The directory for relative script paths
  directory : null

  # all potential file aliases for a particular included file
  aliases : {}

  # the cache of included files
  itemCache : []

  # Bracket delimit for includes
  templateSettings : 
    evaluate    : /{{([\s\S]+?)}}/g,
    interpolate : /{{=([\s\S]+?)}}/g,
    escape      : /{{-([\s\S]+?)}}/g,
    
    # The variable name for all coffeepress
    # template files
    variable    : 'c'

    # Whether to convert tabs to spaces
    convertTabs : true

    # Whether to indent with spaces (default: true)
    spaces : true

    # The standard depth (# of tabs or spaces) of an indent
    indent : 2

  # Settings for the templates that will be pre-compiled and
  # returned in the output
  returnTemplateSettings : 
    evaluate    : /<%([\s\S]+?)%>/g,
    
    interpolate : /<%=([\s\S]+?)%>/g,
    
    escape      : /<%-([\s\S]+?)%>/g,
    
    variable    : 'data'

    namespace   : 'Templates'

  # Variables that have been set for the request
  variables : {}

  # Sets the underscore template settings  
  # mainly useful if you don't want the "variable"  
  # to be data  
  setTemplateSettings : (key, value) ->
    if _.isObject(key)
      for item, value of key
        @returnTemplateSettings[item] = value
    else
      @returnTemplateSettings[key] = value

  # Sets variables for the request
  set : (varName, value) ->
    variables[varName] = value
    return this

  # Gets a variable that has been set for this request
  get : (varName, value) ->
    if @variables[varName]?
      return @variables[varName]
    return value

  # Include this file one time per Coffeepress instance
  once : (items...) ->
    _.reduce(items, (memo, item) ->
      onceItem = @routeFile(item);
      
      if _.isArray(onceItem)
        memo += _.reduce(onceItem, (memo, item) ->
          memo += "\n" + item.text + "\n"
          return memo
        , memo)
      
      else
        memo += "\n" + onceItem.text + "\n"
      
      return memo
    , "", @)

  # Include a file
  include : (items...) ->
    for item in items
      console.log(item)

  buildTree : (item, cache = []) ->
    _.each(fs.readdirSync(item), (p) ->
      if p.charAt(0) is '.'
        return null
      newPath = path.join(item, p)
      if fs.statSync(newPath).isDirectory()
        cache = @buildTree(newPath, cache)
      else
        cache.push(@routeFile(newPath))
    , @)
    return cache

  # Keeps track of every routed file
  routed : []

  # Determines the type of file, and how to handle it
  routeFile : (file) ->
    
    # Check if the last item is a *
    if file.charAt(file.length - 1) is "*"
      pathOpts = [
        path.join(@directory, file.slice(0, -1))
        file.slice(0, -1)
      ]

      for pathOpt in pathOpts
        if fs.existsSync pathOpt
          return @buildTree(pathOpt)

    else
      pathOpts = [
        path.join(@directory, file)
        path.join(@directory, file+'.coffee')
        path.join(@directory, file+'.js')
        file
      ]

      # Run through the potential path destinations
      for pathOpt in pathOpts
        
        # If we've found the file, read and return
        if fs.existsSync pathOpt
          
          if _.indexOf(@routed, pathOpt) is -1
            @routed.push(pathOpt)
            fs.watch pathOpt, (event, filename) =>
              if event is 'change'
                @run.call(@)

          output = fs.readFileSync pathOpt, 'UTF-8'
          
          if @templateSettings.convertTabs is true
            output = output.replace(/\t/g, @repeat(' ', @templateSettings.indent))
          
          relPath  = pathOpt.replace(@directory, '')
          barePath = relPath.split('.')
          
          return {
            text : output,
            path : pathOpt
            relPath : relPath
            pathNoExt : barePath[0]
          }

      throw new Error("The file #{pathOpts.toString()} couldn't be found")

  # Simple repetition of an item
  repeat : (pattern, count) ->
    # copied from objectdump
    `if (count < 1) return '';
    var result = '';
    while (count > 0) {
      if (count & 1) result += pattern;
      count >>= 1, pattern += pattern;
    }`
    return result

  # Whether we've used the template variable yet, and need to wrap
  # the template in a module
  templateVarUsed : false

  # Create an individual template
  template : (name, value) ->
    return name;

  # Returns the output of a template and puts it in an object
  templates : (items..., base = '') ->
    
    allTemplates = _.reduce(items, (memo, item) ->
    
      templateFileDump = @routeFile(item)

      # Run through the array of output items and process each
      if _.isArray(templateFileDump)
        
        memo = _.extend(memo, _.reduce(templateFileDump, (memo, item) ->
          key = item.pathNoExt.replace(base, '')
          memo[key] = _.template(item.text, null, @returnTemplateSettings).source
          return memo
        , memo, @))

      # otherwise this is just a single template, process it as such
      else
        memo[out.pathNoExt] = _.template(out.text, null, @returnTemplateSettings)
      
      return memo

    , {}, @)

    if @templateVarUsed is true
      prefix = "`_.extend(#{@returnTemplateSettings.namespace}, "
      suffix = ")`\n"
    else
      prefix = "`var #{@returnTemplateSettings.namespace} = "
      suffix = "`\n"

    @templateVarUsed = true

    return new ObjectDump(allTemplates).render({
      prefix : prefix
      suffix : suffix
    })


  # Returns a raw javascript file, with ``
  # surrounding the response
  raw : (items...) ->
    
    _.reduce(items, (memo, item) ->
  
      rawItem = @routeFile(item)
  
      if _.isArray(rawItem)
        memo += _.reduce(rawItem, (memo, item) ->
          memo += '`' + item.text.replace(/`/g, '') + "`\n"
          return memo;
        , memo)
      else
        memo += '`' + rawItem.text.replace(/`/g, '') + "`\n"

      return memo
    
    , "", @)
  
  # Read in a file, replacing key with value
  replace : (items..., replace) ->

    key = new RegExp(replace[0], 'g');
    value = replace[1];

    _.reduce(items, (memo, item) ->

      rawItem = @routeFile(item);

      if _.isArray(rawItem)
        memo += _.reduce(rawItem, (memo, item) ->
          memo += item.text.replace(key, value) + "\n"
          return memo;
        , memo)
      else
        memo += rawItem.text.replace(key, value) + "\n"

      return memo

    , "", @)

  # Create an alias to a javascript path,
  # Example Use:
  # cpress = new Coffeepress('file/path')
  # cpress.alias(backbone, __filename + '/public/javascripts/backbone.js')
  # 
  # - In Template:
  # {{= c.press.raw('backbone') }}
  setAlias : (key, value) ->
    @aliases[key] = value
    this

  # Sets a variable which can be used in any templates processed
  # by the coffeepress
  # Example Use:
  # cpress = new Coffeepress('file/path')
  # cpress.setVar(environment, development)
  # 
  # - In Template
  # {{ if (c.environment === 'development') { }} development item... {{ } }}
  setVar : (key, value) ->
    if _.isObject(key)
      for item, value of key
        @variables[item] = value
    else
      @variables[key] = value
    this

  # State of the variables when the coffeepress is run
  runTime : {}

  # Tab the variables according to the template settings
  # Example Use:
  # c.press.tab(2, c.press.once('file/path'));
  tab : (depth, out) ->
    if @templateSettings.spaces is true 
      tabOrSpace = " " 
    else
      tabOrSpace = "\t"
    tabOrSpace = ObjectDump.repeat(null, tabOrSpace, @templateSettings.indent)
    return out.replace(/\n/g, "\n#{ObjectDump.repeat(tabOrSpace, depth)}")

  # callback for the fs watch
  callback : null

  # Run the javascript, with a callback to be run 
  # after the template are all rendered
  run : (callback) ->

    if callback?
      @callback = callback

    # Render the template
    tmpl = _.template(@routeFile(@filename).text, null, @templateSettings);
    
    try
      @callback(null, tmpl(_.extend(@variables, {
        press :
          tab      : _.bind(@tab, @)
          raw      : _.bind(@raw, @)
          once     : _.bind(@once, @)
          replace  : _.bind(@replace, @)
          include  : _.bind(@include, @)
          templates : _.bind(@templates, @)
        }
      )))
      
    catch e
      @callback(e, null)

})

module.exports = Coffeepress