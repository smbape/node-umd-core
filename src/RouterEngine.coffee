deps = [
    {node: 'lodash', common: '!_', amd: 'lodash'}
    './GenericUtil'
    './QueryString'
]
factory = (require, _, GenericUtil, QueryString)->

    hasOwn = {}.hasOwnProperty

    splitPathReg = /^(.*?)([^\/]+?|)(\.[^.\/]*|)$/
    splitPath = (filename) ->
        split = splitPathReg.exec filename

        dirname: split[1]
        filename: split[2]
        extname: split[3]

    NoMatch = (msg)->
        error = new Error msg
        error.code = 'NO_MATCH'
        error

    _removeLeadTrail = do ->
        chars = '[#\\/\\s\\uFEFF\\xA0]+'
        rchars = new RegExp "^#{chars}|#{chars}$", 'g'
        (url)->
            if 'string' is typeof url
                url.replace rchars, ''
            else
                ''

    _substringMatch = (pattern, target)->
        pattern is target or (
            pattern.length < target.length and 
            pattern is target.substring(0, pattern.length) and 
            (pattern is '' or target.charAt(pattern.length) is '/')
        )

    # Class that matches and generates url based on a patter
    #
    # @author Stéphane Mbape
    #
    class RouterEngine
        strict: true
        removeLeadTrail: _removeLeadTrail
        validOptions: ['name', 'strict', 'route', 'baseUrl', 'prefix', 'suffix', 'camel', 'defaults']

        # Construct a new RouterEngine.
        # @param [Object] options the router engine options
        # @option defaults [Object] @see {RouterEngine#setDefaults}
        # @option route [String] @see {RouterEngine#setRoute}
        constructor: (options = {})->
            @defaults = {}
            for prop in RouterEngine::validOptions
                if hasOwn.call options, prop
                    method = 'set' + GenericUtil.StringUtil.firstUpper prop
                    if typeof @[method] is 'function'
                        @[method] options[prop]
                    else
                        @[prop] = options[prop]
            return

        # Method used to encode url parts
        # @param [String] str String to encode
        encode: encodeURIComponent

        # Method used to decode url parts
        # @param [String] str String to decode
        decode: decodeURIComponent

        baseUrl: ''

        setName: (@name)->

        # Parameters used to generate default url when calling RouterEngin.url
        # @param [Object] defaults parts parameters
        setDefaults: (defaults, reset)->
            if not _.isPlainObject defaults
                return

            if reset
                @defaults = defaults
            else
                _.extend @defaults, defaults

            defaultUrl = @getDefaultUrl()
            if defaultUrl isnt @getUrl @getParams defaultUrl
                throw new Error 'Invalid default route'

            return @

        getDefaultUrl: (options)->
            @getUrl @defaults, options

        getVariables: ->
            _.values @variables

        # Set url template
        # @param [String] pattern url pattern template
        # 
        setRoute: (pattern)->
            @pattern = pattern
            @wildcard = false
            variables = @variables = []
            sanitized = []
            regex = []
            inRegExp = false
            inVariable = false
            _variable = null

            map = 
                '*': '[^/]*'
                '/*': '(?:\\/[^/]*|)'
                '**': '.*?'
                '/**': '(?:\\/.*?|)'

            tokenizer = (match, variable, wildcard, expr, special, character, index, str) =>
                if match isnt '}' and inRegExp
                    regex.push match
                    return ''
                else if variable
                    if inVariable
                        throw new Error('Unexpted token ' + match + ' at index ' + index)
                    else
                        inVariable = true
                        # str[i] is not supported in IE8
                        if variable.charAt(variable.length - 1) is ':'
                            inRegExp = true
                            _variable = variable.substring(0, variable.length - 1)
                        else
                            _variable = variable
                    return ''
                else if match is '}'
                    if inVariable
                        if ~variables.indexOf _variable
                            throw new Error('Duplicate variable name ' + _variable)
                        variables.push _variable
                        inVariable = false
                        if inRegExp
                            match = regex.join('')
                            regex = []
                            inRegExp = false
                        else
                            match = '([^/]+)'
                    sanitized.push '{' + _variable + '}'
                else if expr
                    sanitized.push match
                    match = map[match] or match
                else if special
                    sanitized.push match
                    match = map[match] or '\\' + match
                else if wildcard
                    @wildcard = true
                    match = '(?:/(.*)|$)'
                else
                    sanitized.push match
                match

            replacer = @pattern.replace /(?:(?:\{(\w+:?))|(\/\*?\*$)|(\/?\*\*|[\}\/])|([\\^$.|?*+()\[\]{}])|(.))/g, tokenizer
            @replacer = new RegExp('^' + replacer + '$')
            @sanitized = sanitized.join('')

            return @

        setBaseUrl: (baseUrl)->
            if baseUrl is '#'
                @baseUrl = baseUrl
            else if 'string' is typeof baseUrl
                if baseUrl.charAt(baseUrl.length - 1) is '/'
                    @baseUrl = baseUrl
                else
                    @baseUrl = baseUrl + '/'
            @baseUrl

        # Match given url against url template
        # @param [String] url url to match
        # @return [Object] Object of matches
        getParams: (url, options = {}) ->

            url = _removeLeadTrail url
            if url.length is 0
                url = _removeLeadTrail @getDefaultUrl()

            strict = if hasOwn.call options, 'strict'
                options.strict
            else
                @strict

            if not strict
                # Partial match defaultUrl
                defaultUrl = _removeLeadTrail @getDefaultUrl()
                if _substringMatch url, defaultUrl
                    url = defaultUrl

            # Test matching against base url
            baseUrl = _removeLeadTrail @baseUrl
            if not _substringMatch baseUrl, url
                throw NoMatch 'Base url does not match'

            # remove base url form url
            if baseUrl.length > 0
                url = url.substring baseUrl.length + 1

            variables = @variables
            params = {}
            _length = variables.length
            noMatch = true

            url.replace @replacer, (match) =>
                noMatch = false
                for i in [0...variables.length] by 1
                    params[variables[i]] = @decode arguments[i + 1]

                # wildcard
                rest = arguments[variables.length + 1]
                if rest and rest.length isnt 0
                    parts = rest.split('/')
                    for i in [0...parts.length] by 2
                        params[parts[i]] = @decode parts[i + 1]

                return

            if noMatch
                if options.throws is false
                    return false
                else
                    throw NoMatch 'No matching'

            params

        # Generate url from params using url template
        # @param [Object] params
        # @return [String] generated url
        # 
        getUrl: (params = {}, options)->
            params = _.clone params
            for key of @defaults
                if not hasOwn.call params, key
                    params[key] = _.result @defaults, key

            for own key of params
                params[key] = _.result params, key

            url = @sanitized.replace /\{(\w+)\}/g, (match, variable) =>
                if hasOwn.call params, variable
                    match = @encode params[variable]
                    delete params[variable]
                match

            if @wildcard
                extra = []
                for own key of params
                    if params[key]
                        extra.push.call extra, key, @encode params[key]
                url += '/' + extra.join '/' if extra.length > 0

            baseUrl = @baseUrl
            if _.isObject(options)
                baseUrl = '' if options.noBase
                if options.query
                    query = QueryString.stringify options.query
                    if not _.isEmpty query
                        url += '?' + query

            baseUrl + url

        getFilePath: (params, options)->
            url = @getUrl params, _.defaults {noBase: true}, options
            return if not url
            url = splitPath url.toLowerCase()
            url.filename = GenericUtil.StringUtil.toCapitalCamelDash url.filename if @camel
            url.filename = @prefix + url.filename if @prefix
            url.filename += @suffix if @suffix
            if typeof @basePath is 'string' and @basePath.length > 0
                sep = @basePath.charAt @basePath.length - 1
                if not /[\\/]/.test sep
                    sep = '/'
                url.dirname = @basePath + sep + url.dirname
            return url.dirname + url.filename + url.extname

        match: (url)->
            try
                return @getParams url if typeof url is 'string' and url.length > 0
            catch ex
            return false

        getShortUrl: (params, options)->
            if 'string' is typeof params
                params = @getParams params
            variables = @getVariables()
            mandatoryParams = _.pick params, variables
            @getUrl mandatoryParams, options
