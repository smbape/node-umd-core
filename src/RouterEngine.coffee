`
import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
import qs from './QueryString';
import StringUtil from './util/StringUtil';
`

# TODO : perf

{ firstUpper, toCapitalCamelDash } = StringUtil
{ hasOwnProperty: hasProp } = Object.prototype
{ push } = Array.prototype

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

_removeLeadTail = do ->
    chars = '[#\\/\\s\\uFEFF\\xA0]+'
    rchars = new RegExp "^#{chars}|#{chars}$", 'g'
    (url)->
        if 'string' is typeof url
            url.replace rchars, ''
        else
            url

_substringMatch = (pattern, target)->
    length = pattern.length
    pattern is target or (
        length < target.length and
        pattern is target.substring(0, length) and
        (pattern is '' or target[length] is '/')
    )

# Class that matches and generates url based on a patter
#
# @author Stéphane Mbape
#
class RouterEngine
    strict: true
    removeLeadTail: _removeLeadTail
    validOptions: ['name', 'strict', 'route', 'baseUrl', 'prefix', 'suffix', 'camel', 'defaults']

    # Method used to encode url parts
    # @param [String] str String to encode
    encode: encodeURIComponent

    # Method used to decode url parts
    # @param [String] str String to decode
    decode: decodeURIComponent

    baseUrl: ''

    # Construct a new RouterEngine.
    # @param [Object] options the router engine options
    # @option defaults [Object] @see {RouterEngine#setDefaults}
    # @option route [String] @see {RouterEngine#setRoute}
    constructor: (options = {})->
        @defaults = {}
        for prop in RouterEngine::validOptions
            if hasProp.call options, prop
                method = 'set' + firstUpper prop
                if typeof @[method] is 'function'
                    @[method] options[prop]
                else
                    @[prop] = options[prop]
        return

    setName: (@name)->

    # Parameters used to generate default url when calling RouterEngin.url
    # @param [Object] defaults parts parameters
    setDefaults: (defaults, reset)->
        if not _.isObject defaults
            return

        if reset
            @defaults = Object.assign {}, defaults
        else
            Object.assign @defaults, defaults

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
        engine = this
        engine.pattern = pattern
        engine.wildcard = false
        variables = engine.variables = []
        sanitized = []
        regex = []
        inRegExp = false
        inVariable = false
        varname = null

        map =
            '*': '[^/]*'
            '/*': '(?:\\/[^/]*|)'
            '**': '.*?'
            '/**': '(?:\\/.*?|)'

        tokenizer = (match, variable, wildcard, expr, special, character, index, str) ->
            if match isnt '}' and inRegExp
                regex.push match
                return ''

            if variable
                if inVariable
                    throw new Error('Unexpted token ' + match + ' at index ' + index)
                else
                    inVariable = true
                    if variable[variable.length - 1] is ':'
                        inRegExp = true
                        varname = variable.substring(0, variable.length - 1).trim()
                    else
                        varname = variable.trim()
                return ''

            if match is '}'
                if inVariable
                    if variables.indexOf(varname) isnt -1
                        throw new Error('Duplicate variable name ' + varname)
                    variables.push varname
                    inVariable = false
                    if inRegExp
                        match = regex.join('').trim()
                        regex = []
                        inRegExp = false
                    else
                        match = '([^/]+)'
                sanitized.push '{' + varname + '}'
            else if expr
                sanitized.push match
                match = map[match] or match
            else if special
                sanitized.push match
                match = map[match] or '\\' + match
            else if wildcard
                engine.wildcard = true
                match = '(?:/(.*)|$)'
            else
                sanitized.push match
            match

        matcher = engine.pattern.replace /(?:(?:\{\s*(\w+\s*:?)\s*)|(\/\*?\*$)|(\/?\*\*|[\}\/])|([\\^$.|?*+()\[\]{}])|(.))/g, tokenizer
        engine.matcher = new RegExp('^' + matcher + '$')
        engine.sanitized = sanitized.join('')

        return engine

    setBaseUrl: (baseUrl)->
        if baseUrl is '#'
            @baseUrl = baseUrl
        else if 'string' is typeof baseUrl
            if baseUrl is '' or baseUrl[baseUrl.length - 1] is '/'
                @baseUrl = baseUrl
            else
                @baseUrl = baseUrl + '/'
        @baseUrl

    # Match given url against url template
    # @param [String] url url to match
    # @return [Object] Object of matches
    getParams: (url, options = {}) ->
        engine = this

        strict = if hasProp.call options, 'strict'
            options.strict
        else
            engine.strict

        url = _removeLeadTail url

        if not strict
            if url.length is 0
                url = _removeLeadTail engine.getDefaultUrl()

            # Partial match defaultUrl
            defaultUrl = _removeLeadTail engine.getDefaultUrl()
            if _substringMatch url, defaultUrl
                url = defaultUrl

        # Test matching against base url
        baseUrl = _removeLeadTail engine.baseUrl
        if not _substringMatch baseUrl, url
            throw NoMatch 'Base url does not match'

        # remove base url form url
        if baseUrl.length > 0
            url = url.substring baseUrl.length + 1

        variables = engine.variables
        pathParams = {}
        wildParams = {}
        _length = variables.length
        noMatch = true

        replace = (match) ->
            noMatch = false
            for i in [0...variables.length] by 1
                pathParams[variables[i]] = engine.decode arguments[i + 1]

            # wildcard
            remaining = arguments[variables.length + 1]
            if remaining and remaining.length isnt 0
                parts = remaining.split('/')
                for i in [0...parts.length] by 2
                    wildParams[parts[i]] = engine.decode parts[i + 1]

            return

        url.replace engine.matcher, replace

        if noMatch and options.partial
            # replace missing parts with default url parts
            if !defaultUrl
                defaultUrl = _removeLeadTail engine.getDefaultUrl()
            parts = defaultUrl.split(/\//g)
            for part, i in url.split(/\//g)
                parts[i] = part
            parts.join("/").replace engine.matcher, replace

        if noMatch
            if options.throws is false
                return false
            else
                throw NoMatch 'No matching'

        if (options.separate)
            return { pathParams, wildParams }

        return Object.assign(pathParams, wildParams)

    # Generate url from params using url template
    # @param [Object] params
    # @return [String] generated url
    getUrl: (params = {}, options)->
        self = @

        params = Object.assign {}, params
        for key of @defaults
            if not hasProp.call params, key
                params[key] = _.result @defaults, key

        for own key of params
            params[key] = _.result params, key

        url = self.sanitized.replace /\{(\w+)\}/g, (match, variable) ->
            if hasProp.call params, variable
                match = self.encode params[variable]
                delete params[variable]
            match

        url = [url]

        if @wildcard
            remaining = []
            for own key of params
                if params[key]
                    remaining.push key, @encode params[key]

            push.call url, '/', remaining.join '/' if remaining.length > 0

        baseUrl = @baseUrl

        if _.isObject(options)
            baseUrl = '' if options.noBase
            query = options.query

            if _.isObject query
                query = qs.stringify query

            if 'string' is typeof query and query.length isnt 0
                push.call url, '?', query

            hash = options.hash
            if 'string' is typeof hash and hash.length isnt 0
                hashChar = options.hashChar or '#'
                push.call url, hashChar, hash

        return baseUrl + url.join('')

    getFilePath: (params, options)->
        url = @getUrl params, _.defaults {noBase: true}, options
        return if not url
        url = splitPath url.toLowerCase()
        url.filename = toCapitalCamelDash url.filename if @camel
        url.filename = @prefix + url.filename if @prefix
        url.filename += @suffix if @suffix
        if typeof @basePath is 'string' and @basePath.length > 0
            sep = @basePath[@basePath.length - 1]
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

module.exports = RouterEngine
