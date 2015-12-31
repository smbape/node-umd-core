factory = (require)->
    toString = ({}).toString;
    hasOwnProperty = Object::hasOwnProperty
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

    GenericUtil.StringUtil =
        capitalize: (str) ->
            str.charAt(0).toUpperCase() + str.slice(1).toLowerCase()

        firstUpper: (str) ->
            str.charAt(0).toUpperCase() + str.slice 1

        toCamelDash: (str) ->
            str.replace /\-(\w)/g, (match) ->
                match[1].toUpperCase()

        toCapitalCamelDash: (str) ->
            GenericUtil.StringUtil.toCamelDash GenericUtil.StringUtil.capitalize str

        toCamelSpaceDash: (str) ->
            str.replace /\-([a-z])/g, (match) ->
                ' ' + match[1].toUpperCase()

        toCapitalCamelSpaceDash: (str) ->
            GenericUtil.StringUtil.toCamelSpaceDash GenericUtil.StringUtil.capitalize str

        firstSubstring: (str, n) ->
            return str if typeof str isnt "string"
            return '' if n >= str.length
            str.substring 0, str.length - n

        lastSubstring: (str, n) ->
            return str if typeof str isnt "string"
            return str if n >= str.length
            str.substring str.length - n, str.length

    ((StringUtil)->
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
    )(GenericUtil.StringUtil)

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

    ((comparators)->
        comparators.compareProperty = compareProperty = (a, b, property)->
                if a instanceof Backbone.Model
                    a = a.attributes
                if b instanceof Backbone.Model
                    b = b.attributes

                if a[property] > b[property]
                    1
                else if a[property] < b[property]
                    -1
                else
                    0

        comparators.PropertyComarator = (property)->
            (a, b)->
                compareProperty a, b, property

        comparators.PropertiesComparator = (properties)->
            (a, b)->
                for property in properties
                    if 0 isnt (res = compareProperty a, b, property)
                        return res

                0

        comparators.reverse = (compare)->
            return compare.original if compare.reverse and compare.original

            fn = (a, b)->
                -compare(a, b)

            fn.reverse = true
            fn.original = compare

            fn

        comparators.binaryIndex = (value, array, compare, fromIndex = 0)->
            if fromIndex < 0
                high = array.length
                low = high - fromIndex
            else
                high = array.length
                low = fromIndex

            while low < high
                mid = (low + high) >> 1
                if 0 > compare array[mid], value
                    low = mid + 1
                else
                    high = mid

            if array[low] is value then low else -1

        return
    )(GenericUtil.comparators = {})

    return GenericUtil