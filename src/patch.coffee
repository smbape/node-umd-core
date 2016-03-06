deps = [
    {amd: 'jquery', common: '!jQuery'}
]

factory = ($)->

    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/bind#Polyfill
    unless Function::bind
        Function::bind = (oThis) ->
            if typeof this isnt 'function'
                # closest thing possible to the ECMAScript 5
                # internal IsCallable function
                throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable')
            aArgs = Array::slice.call(arguments, 1)
            fToBind = this

            fNOP = ->

            fBound = ->
                fToBind.apply (if this instanceof fNOP then this else oThis), aArgs.concat(Array::slice.call(arguments))

            if @prototype
                # Function.prototype doesn't have a prototype property
                fNOP.prototype = @prototype
            fBound.prototype = new fNOP()
            fBound

    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/isArray#Polyfill
    unless Array.isArray
        Array.isArray = (arg) ->
            Object::toString.call(arg) is '[object Array]'

    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/keys#Polyfill
    unless Object.keys
        do ->
            hasOwnProperty = Object::hasOwnProperty
            hasDontEnumBug = !{ toString: null }.propertyIsEnumerable('toString')
            dontEnums = [
                'toString'
                'toLocaleString'
                'valueOf'
                'hasOwnProperty'
                'isPrototypeOf'
                'propertyIsEnumerable'
                'constructor'
            ]
            dontEnumsLength = dontEnums.length
            Object.keys = (obj) ->
                if typeof obj isnt 'object' and (typeof obj isnt 'function' or obj == null)
                    throw new TypeError('Object.keys called on non-object')
                result = []

                for prop of obj
                    if hasOwnProperty.call(obj, prop)
                        result.push prop
                if hasDontEnumBug
                    for i in [0...dontEnumsLength] by 1
                        if hasOwnProperty.call(obj, dontEnums[i])
                            result.push dontEnums[i]
                result
            return

    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/Trim#Polyfill
    unless String::trim
        do ->
            rtrim = /^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g
            String::trim = ->
                @replace rtrim, ''
            return

    discard = (element) ->
        # http://jsperf.com/emptying-a-node
        discard element.lastChild while element.lastChild
        if element.nodeType is 1 and not /^(?:IMG|SCRIPT|INPUT)$/.test element.nodeName
            element.innerHTML = ''
        element.parentNode.removeChild element if element.parentNode
        return

    $.fn.destroy = (selector) ->
        ret = this.remove()
        i = 0
        while (elem = this[i])?
            # Remove any remaining nodes
            discard elem
            i++
        ret

    $.fn.insertAt = (index, elements)->
        @domManip [elements], (elem) ->
            if this.children
                if this.children.length < index
                    this.appendChild elem
                else if index < 0
                    this.insertBefore elem, this.firstChild
                else
                    this.insertBefore elem, this.children[index]
            else
                this.appendChild elem
            return

    # # http://stackoverflow.com/questions/333634/http-head-request-in-javascript-ajax#333657
    # urlExists = (url, callback) ->
    #     http = new XMLHttpRequest()
    #     http.open 'HEAD', url

    #     http.onreadystatechange = ->
    #         if @readyState is @DONE
    #             callback @status is 200
    #         return

    #     http.send()
    #     return

    # # try a faster error notfication for url that doesn't exists
    # if 'undefined' isnt typeof requirejs
    #     load = requirejs.load

    #     requirejs.load = (context, moduleName, url) ->
    #         config = (context and context.config) or {}
    #         node = requirejs.createNode(config, moduleName, url)
    #         node.setAttribute 'data-requirecontext', context.contextName
    #         node.setAttribute 'data-requiremodule', moduleName
    #         node.src = url

    #         urlExists node.src, (exists)->
    #             if not exists
    #                 evt = document.createEvent('Event')
    #                 evt.initEvent('error', true, true)
    #                 node.addEventListener('error', context.onScriptError, false)
    #                 node.dispatchEvent(evt)
    #                 return

    #             load context, moduleName, url
    #             return

    #         node
    #         return

    return
