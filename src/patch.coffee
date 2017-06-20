deps = [
    {amd: 'jquery', common: 'jquery', brunch: '!jQuery'}
    "../lib/Polyfill/Array/isArray"
    "../lib/Polyfill/Function/bind"
    "../lib/Polyfill/Object/keys"
    "../lib/Polyfill/String/trim"
]

factory = ($)->

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
                    if this.frameCount_ is -1
                        setTimeout =>
                            $.removeData this.element_, 'ripple'

                            this.element_.removeEventListener('mousedown', this.boundDownHandler)
                            this.element_.removeEventListener('touchstart', this.boundDownHandler)
                            this.element_.removeEventListener('mouseup', this.boundUpHandler)
                            this.element_.removeEventListener('mouseleave', this.boundUpHandler)
                            this.element_.removeEventListener('touchend', this.boundUpHandler)
                            this.element_.removeEventListener('blur', this.boundUpHandler)

                            for own prop of this
                                delete this[prop]
                            return
                        , 0
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
