`
import _ from "%{amd: 'lodash', brunch: '!_', common: 'lodash', node: 'lodash'}";
`

makeError = (error, options = {}, config)->
    if not _.isEmpty(config)
        switch typeof config.msg
            when 'string'
                return config.msg
            when 'function'
                return config.msg error, options

        if _.isObject(config.translator) and 'function' is typeof config.translator.t
            return config.translator.t error, options

    return {error, options}

# Determines whether or not a value is empty
hasValue = (value) ->
    switch typeof value
        when 'undefined'
            return true
        when 'string'
            return /^\s*$/.test(value)
        when 'object'
            return true if value is null
            return value.length is 0 if Array.isArray(value)

    return false

defaultOptions = {}

module.exports =
    defaults: defaultOptions

    error: (err, options)->
        makeError err, options, defaultOptions

    getOptions: (validator)->
        validator?.fn?.options

    email: (config)->
        config = Object.assign {}, defaultOptions, config
        fn: (value, attr, computed)->
            if 'string' is typeof value and not /^.+@.+\..+$/.test value
                if 'function' is typeof config.label
                    attr = config.label(attr)
                makeError 'error.email', {field: attr}, config

    pattern: (pattern, config)->
        config = Object.assign {}, defaultOptions, config
        return if not _.isRegExp(pattern)

        fn = (value, attr, computed)->
            if 'string' is typeof value and not pattern.test value
                if 'function' is typeof config.label
                    attr = config.label(attr)
                makeError 'error.pattern', {field: attr, pattern}, config

        fn.options = {pattern}

        {fn}

    required: (config)->
        config = Object.assign {}, defaultOptions, config
        fn: (value, attr, computed)->
            if hasValue(value)
                if 'function' is typeof config.label
                    attr = config.label(attr)
                makeError 'error.required', {field: attr}, config

    either: (list, config)->
        config = Object.assign {}, defaultOptions, config
        return if not Array.isArray list
        fn: (value, attr, computed) ->
            invalid = true
            for attr in list
                if 'string' is typeof computed[attr] and computed[attr].length > 0
                    invalid = false
                    break

            if invalid
                if 'function' is typeof config.label
                    attr = config.label(attr)
                makeError 'error.either', {list: list.join(', '), field: attr}, config

    range: (minLength, maxLength, config)->
        config = Object.assign {}, defaultOptions, config
        fn = (value, attr, computed) ->
            if typeof value is 'string'
                if value.length > maxLength
                    makeError 'error.maxLength', {maxLength: maxLength, given: value.length}, config
                else if value.length < minLength
                    makeError 'error.minLength', {minLength: minLength, given: value.length}, config

        fn.options = {minLength, maxLength}

        {fn}

    maxLength: (maxLength, config)->
        config = Object.assign {}, defaultOptions, config
        fn = (value, attr, computed) ->
            if typeof value is 'string' and value.length > maxLength
                makeError 'error.maxLength', {maxLength: maxLength, given: value.length}, config

        fn.options = {maxLength}

        {fn}

    minLength: (minLength, config)->
        config = Object.assign {}, defaultOptions, config
        fn = (value, attr, computed) ->
            if typeof value is 'string' and value.length < minLength
                makeError 'error.minLength', {minLength: minLength, given: value.length}, config

        fn.options = {minLength}

        {fn}

    length: (length, config)->
        config = Object.assign {}, defaultOptions, config
        fn = (value, attr, computed) ->
            if typeof value isnt 'string' or value.length isnt length
                makeError 'error.length', {length: length, given: value.length}, config

        fn.options = {length}

        {fn}

    password: (config)->
        config = Object.assign {}, defaultOptions, config
        fn: (value, attr, computed) ->
            errorList = []
            if typeof value is 'string' and value.length < 6
                errorList.push makeError 'error.minLength', {minLength: 6, given: value.length}, config

            if typeof value is 'string' and value.length > 255
                errorList.push makeError 'error.maxLength', {maxLength: 6, given: value.length}, config

            errorsArray = [
                'digit'
                'lowercase'
                'uppercase'
                'special'
            ]

            re = /([\da-zA-Z]|[^\t\r\n\w])/g
            while (match = re.exec(value))
                errorsArray.splice(errorsArray.indexOf('digit'), 1) if ~errorsArray.indexOf('digit') and /\d/.test match[0]
                errorsArray.splice(errorsArray.indexOf('lowercase'), 1) if ~errorsArray.indexOf('lowercase') and /[a-z]/.test match[0]
                errorsArray.splice(errorsArray.indexOf('uppercase'), 1) if ~errorsArray.indexOf('uppercase') and /[A-Z]/.test match[0]
                errorsArray.splice(errorsArray.indexOf('special'), 1) if ~errorsArray.indexOf('special') and /[^\t\r\n\w]/.test match[0]
                if errorsArray.length is 0
                    break

            for error in errorsArray
                errorList.push makeError error, null, config

            errorList if errorList.length > 0
