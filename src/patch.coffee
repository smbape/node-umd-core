deps = [
    {amd: 'jquery', common: 'jquery', brunch: '!jQuery'}
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

    hasProp = Object::hasOwnProperty
    emptyFn = Function.prototype

    # https://github.com/WICG/EventListenerOptions/blob/gh-pages/explainer.md
    supportsPassive = do ->
        # Test via a getter in the options object to see if the passive property is accessed
        supportsPassive = false

        try
            opts = Object.defineProperty({}, 'passive', get: ->
                supportsPassive = true
                return
            )
            window.addEventListener 'test', null, opts
        catch e
        supportsPassive

    captureOptions = if supportsPassive then passive: true else false

    supportOnPassive = ($, name)->
        if !captureOptions
            return emptyFn

        if /\s/.test(name)
            names = name.split(/\s+/g)
            destroyers = []
            for name in names
                destroyers.push supportOnPassive($, name)
            return ->
                for i in [destroyers.length - 1...-1] by -1
                    destroyers[i]()
                destroyers = null
                return

        special = $.event.special
        if hasProp.call special, name
            hasSpecial = true
            if hasProp.call special[name], "setup"
                preSetup = special[name].setup
                if preSetup.passiveSupported
                    return emptyFn
                hasPrevSetup = true
        else
            special[name] = {}

        setup = special[name].setup = (data, namespaces, eventHandle)->
            @addEventListener( name, eventHandle, captureOptions )
            return

        setup.passiveSupported = true

        ->
            if hasPrevSetup
                special[name].setup = preSetup
                preSetup = null
            else if hasSpecial
                delete special[name].setup
            else
                delete special[name].setup
                delete special[name]

            name = null
            special = null
            $ = null
            return

    { MaterialRipple } = window

    if MaterialRipple
        # delegated ripple effect

        rippleEvents = 'mousedown touchstart mouseup mouseleave touchend blur'
        restore = supportOnPassive($, rippleEvents)

        $(document).on rippleEvents, '.mdl-js-ripple-effect:not([data-upgraded]) .mdl-button__ripple-container', (evt)->
            element_ = evt.currentTarget.parentNode
            ripple = $.data element_, 'ripple'

            if not ripple
                ripple = new MaterialRipple(element_)
                $.data element_, 'ripple', ripple
                setRippleStyles = ripple.setRippleStyles
                ripple.setRippleStyles = (start)->
                    setRippleStyles.call this, start
                    if this.frameCount_ is 0
                        $.removeData this.element_, 'ripple'

                        this.element_.removeEventListener('mousedown', this.boundDownHandler)
                        this.element_.removeEventListener('touchstart', this.boundDownHandler)
                        this.element_.removeEventListener('mouseup', this.boundUpHandler)
                        this.element_.removeEventListener('mouseleave', this.boundUpHandler)
                        this.element_.removeEventListener('touchend', this.boundUpHandler)
                        this.element_.removeEventListener('blur', this.boundUpHandler)

                        # delete this.element_
                        for own prop of this
                            delete this[prop]
                    return

            overridedEvt = {}
            for prop of evt.originalEvent
                overridedEvt[prop] = evt.originalEvent[prop]
            overridedEvt.currentTarget = element_

            switch evt.type
                when 'mousedown', 'touchstart'
                    ripple.downHandler_(overridedEvt)
                when 'mouseup', 'mouseleave', 'touchend', 'blur'
                    ripple.upHandler_(overridedEvt)

            return

        restore()

    return
