deps = ['../common']

factory = ({_, i18n})->
    makeError = (error, options)->
        {error, options}


    # Determines whether or not a value is empty
    isEmpty = (value) ->
        switch typeof value
            when 'undefined'
                return true
            when 'string'
                return /^\s*$/.test(value)
            when 'object'
                return true if value is null
                return value.length is 0 if _.isArray(value)
        
        return false

    email: (options)->
        fn: (value, attr, computed)->
            if 'string' is typeof value and not /^.+@.+\..+$/.test value
                attr = if 'function' is typeof options?.label then options.label(attr) else "'" + attr + "'"
                makeError 'error.email', {field: attr}

    pattern: (pattern)->
        return if not _.isRegExp(pattern)
        fn: (value, attr, computed)->
            if 'string' is typeof value and not pattern.test value
                attr = if 'function' is typeof options?.label then options.label(attr) else "'" + attr + "'"
                makeError 'error.pattern', {field: attr, pattern}

    required: fn: (value, attr, computed)->
        if isEmpty(value)
            makeError 'error.required_field', field: attr

    either: (list)->
        return if not _.isArray list
        fn: (value, attr, computed) ->
            invalid = true
            for attr in list
                if 'string' is typeof computed[attr] and computed[attr].length > 0
                    invalid = false
                    break

            if invalid
                makeError 'error.either', list: list.join(', ')

    range: (minLength, maxLength)->
        fn: (value, attr, computed) ->
            if typeof value is 'string'
                if value.length > maxLength
                    makeError 'error.maxLength',
                        maxLength: maxLength
                        given: value.length
                else if value.length < minLength
                    makeError 'error.minLength',
                        minLength: minLength
                        given: value.length

    maxLength: (maxLength)->
        fn: (value, attr, computed) ->
            if typeof value is 'string' and value.length > maxLength
                makeError 'error.maxLength',
                    maxLength: maxLength
                    given: value.length

    minLength: (minLength)->
        fn: (value, attr, computed) ->
            if typeof value is 'string' and value.length < minLength
                makeError 'error.minLength',
                    minLength: minLength
                    given: value.length

    length: (length)->
        fn: (value, attr, computed) ->
            if typeof value isnt 'string' or value.length isnt length
                makeError 'error.length',
                    length: length
                    given: value.length

    password: fn: (value, attr, computed) ->
        errorList = []
        if typeof value is 'string' and value.length < 6
            errorList.push makeError 'error.minLength',
                minLength: 6
                given: value.length

        if typeof value is 'string' and value.length > 255
            errorList.push makeError 'error.maxLength',
                maxLength: 6
                given: value.length

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
            errorList.push makeError error

        errorList if errorList.length > 0