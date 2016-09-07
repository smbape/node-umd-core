deps = []

factory = ->
    toString = Object::toString
    hasOwn = Object::hasOwnProperty
    slice = Array::slice
    splice = Array::splice

    extend = (target, obj)->
        for own prop of obj
            target[prop] = obj[prop]

    GenericUtil =

        # Based on jQuery 1.11
        isArray: Array.isArray or (obj)->
            '[object Array]' is toString.call obj

        # Based on jQuery 1.11
        isNumeric: (obj) ->
            !GenericUtil.isArray( obj ) and (obj - parseFloat( obj ) + 1) >= 0

        isWindow: (obj) ->
            # jshint eqnull: true, eqeqeq: false
            obj? and obj is obj.window

        isObject: (obj) ->
            typeof obj is 'object' and obj isnt null

        notEmptyString: (str)->
            typeof str is 'string' and str.length > 0

        throttle: (fn, delay = 0, alwaysDefer) ->
            last = undefined
            deferTimer = undefined
            ->
                context = this
                args = slice.call arguments
                now = +new Date
                if last and now < last + delay
                    clearTimeout deferTimer
                    deferTimer = setTimeout ->
                        last = now
                        fn.apply context, args
                        return
                    , delay
                else
                    if alwaysDefer
                        setTimeout ->
                            last = now
                            fn.apply context, args
                        , delay
                    else
                        last = now
                        fn.apply context, args
                return

        mergeFunctions: ->
            fns = []
            size = 0

            for arg in arguments
                if 'function' is typeof arg
                    fns.push arg
                    ++size

            if size is 0 or size is 1
                return fns[0]

            func = ->
                for fn in fns
                    fn.apply null, arguments
                return

            func

    class GenericUtil.Timer
        constructor: ->
            @data = {}

        set: (s, fn, ms)->
            @clear s

            _fn = =>
                @clear s
                fn()

            @data[s] = setTimeout _fn, ms
            return

        clear: (s) ->
            t = @data
            if t[s]
                clearTimeout t[s]
                delete t[s]
            return

        clearAll: ->
            for s of @data
                @clear s
            return

    class GenericUtil.Interval
        constructor: ->
            @data = {}

        set: (s, fn, ms)->
            @clear s
            @data[s] = setInterval fn, ms
            return

        clear: (s) ->
            t = @data
            if t[s]
                clearInterval t[s]
                delete t[s]
            return

        clearAll: ->
            for s of @data
                @clear s
            return

    ((StringUtil)->
        extend StringUtil,
            escapeRegExp: (str)->
                str.replace /([\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}])/g, '\\$1'

            capitalize: (str) ->
                str.charAt(0).toUpperCase() + str.slice(1).toLowerCase()

            firstUpper: (str) ->
                str.charAt(0).toUpperCase() + str.slice 1

            toCamel: (str, mark = '-')->
                if commonCamel[mark]
                    return commonCamel[mark].toCamel str

                reg = new RegExp StringUtil.escapeRegExp(mark) + '\\w', 'g'
                str.replace reg, (match) ->
                    match[1].toUpperCase()

            toCapitalCamel: (str, mark) ->
                if commonCamel[mark]
                    return commonCamel[mark].toCapitalCamel str

                reg = new RegExp '(?:^|' + StringUtil.escapeRegExp(mark) + ')(\\w)', 'g'
                str.replace reg, (match, letter)->
                    letter.toUpperCase()

            toCamelDash: (str) ->
                str.replace /-(\w)/g, (match) ->
                    match[1].toUpperCase()

            toCapitalCamelDash: (str) ->
                StringUtil.toCamelDash StringUtil.capitalize str

            firstSubstring: (str, n) ->
                return str if typeof str isnt "string"
                return '' if n >= str.length
                str.substring 0, str.length - n

            lastSubstring: (str, n) ->
                return str if typeof str isnt "string"
                return str if n >= str.length
                str.substring str.length - n, str.length

        commonCamel =
            '-':
                toCamel: (str)->
                    str.replace /-\w/g, (match) ->
                        match[1].toUpperCase()
                toCapitalCamel: (str) ->
                    str.replace /(?:^|-)(\w)/g, (match, letter)->
                        letter.toUpperCase()
            ':':
                toCamel: (str)->
                    str.replace /:\w/g, (match) ->
                        match[1].toUpperCase()
                toCapitalCamel: (str) ->
                    str.replace /(?:^|:)(\w)/g, (match, letter)->
                        letter.toUpperCase()
            ' ': 
                toCamel: (str) ->
                    str.replace RegExp(' \\w', 'g'), (match) ->
                        match[1].toUpperCase()
                toCapitalCamel: (str) ->
                    str.replace /(?:^| )(\w)/g, (match, letter) ->
                        letter.toUpperCase()

        _entityMap =
            '&': '&amp;'
            '<': '&lt;'
            '>': '&gt;'
            '"': '&quot;'
            "'": '&#39;'
            '/': '&#x2F;'

        StringUtil.escapeHTML = (html) ->
            if typeof html is 'string'
                html.replace /[&<>"'\/]/g, (s) ->
                    _entityMap[s]
            else
                html
        return
    )(GenericUtil.StringUtil = {})

    GenericUtil.ArrayUtil =
        clone: (arr) ->
            Array::slice.call arr, 0

        backIndex: (arr, n) ->
            arr[arr.length - 1 - n]

        flip: (arr) ->
            key = undefined
            tmp_ar = undefined
            tmp_ar = {}
            for key of arr
                tmp_ar[arr[key]] = key if arr.hasOwnProperty key
            tmp_ar

    ((sql)->
        STATIC =
            MYSQL: 'mysql'
            POSTGRES: 'postgres'

        _escapeMap = {}
        _escapeMap[STATIC.MYSQL] =
            id:
                quote: '`'
                matcher: /([`\\\0\n\r\b])/g
                replace:
                    '`': '\\`'
                    '\\': '\\\\'
                    '\0': '\\0'
                    '\n': '\\n'
                    '\r': '\\r'
                    '\b': '\\b'
            literal:
                quote: "'"
                matcher: /(['\\\0\n\r\b])/g
                replace:
                    "'": "\\'"
                    '\\': '\\\\'
                    '\0': '\\0'
                    '\n': '\\n'
                    '\r': '\\r'
                    '\b': '\\b'

        _escapeMap[STATIC.POSTGRES] =
            id:
                quote: '"'
                matcher: /(["\\\0\n\r\b])/g
                replace:
                    '"': '""'
                    '\0': '\\0'
                    '\n': '\\n'
                    '\r': '\\r'
                    '\b': '\\b'
            literal:
                quote: "'"
                matcher: /(['\\\0\n\r\b])/g
                replace:
                    "'": "''"
                    '\0': '\\0'
                    '\n': '\\n'
                    '\r': '\\r'
                    '\b': '\\b'

        _escape = (str, map)->
            type = typeof str
            if type is 'number'
                return str
            if type is 'boolean'
                return if type then '1' else '0'
            if GenericUtil.isArray str
                ret = []
                for iStr in str
                    ret[ret.length] = _escape iStr, map
                return '(' + ret.join(', ') + ')'

            if 'string' isnt type
                # console.warn("escape - Bad string", str)
                str = '' + str
            str = str.replace map.matcher, (match, char, index, str)->
                map.replace[char]
            return map.quote + str + map.quote

        sql.escapeId = (str, dialect = STATIC.POSTGRES)->
            return _escape str, _escapeMap[dialect].id

        sql.escape = (str, dialect = STATIC.POSTGRES)->
            return _escape str, _escapeMap[dialect].literal

        return
    )(GenericUtil.sql = {})

    ((DOMUtil)->
        # http://stackoverflow.com/questions/384286/javascript-isdom-how-do-you-check-if-a-javascript-object-is-a-dom-object#384380

        #Returns true if it is a DOM node
        DOMUtil.isNode = (o) ->
            if typeof Node is 'object' then o instanceof Node else o and typeof o is 'object' and typeof o.nodeType is 'number' and typeof o.nodeName is 'string'

        #Returns true if it is a DOM element    
        DOMUtil.isElement =(o) ->
            if typeof HTMLElement is 'object' then o instanceof HTMLElement else o and typeof o is 'object' and o isnt null and o.nodeType is 1 and typeof o.nodeName is 'string'

        DOMUtil.isNodeOrElement =(o)->
            DOMUtil.isNode(o) or DOMUtil.isElement(o)

        DOMUtil.discardElement = (element) ->
            # http://jsperf.com/emptying-a-node
            DOMUtil.discardElement element.lastChild while element.lastChild
            if element.nodeType is 1 and not /^(?:IMG|SCRIPT|INPUT)$/.test element.nodeName
                element.innerHTML = ''
            element.parentNode.removeChild element if element.parentNode
            return

        return
    )(GenericUtil.DOMUtil = {})

    return GenericUtil