deps = [
    '../common'
    './AbstractModelComponent'
    '../../lib/dialogPolyfill'
    '../functions/getMatchingCssStyle'
]

freact = ({_}, AbstractModelComponent, dialogPolyfill, getMatchingCssStyle)->

    testElementStyle = document.createElement('div').style
    transformJSPropertyName = if 'transform' of testElementStyle then 'transform' else 'webkitTransform'
    transitionJSPropertyName = if 'transition' of testElementStyle then 'transition' else 'webkitTransition'
    testElementStyle = null
    CSSMatrix = window.WebKitCSSMatrix or window.MSCSSMatrix

    class Dialog extends AbstractModelComponent
        componentDidMount: ->
            super
            el = @el
            if el.tagName is 'DIALOG' and not el.showModal
                polyfill = @polyfill = dialogPolyfill.registerDialog el

                setOpen = polyfill.setOpen
                polyfill.setOpen = (value)->
                    setOpen.call polyfill, value
                    widthAttributes = [
                        "width"
                        "minWidth"
                        "maxWidth"
                    ]

                    body = el.ownerDocument.body

                    if not value
                        if CSSMatrix
                            parentNode = el.parentNode
                            while parentNode and parentNode isnt body
                                transform = getMatchingCssStyle(parentNode, "transform")
                                if transform
                                    if parentNode.hasAttribute("data-original-zIndex")
                                        zIndex = parentNode.getAttribute("data-original-zIndex")
                                        parentNode.removeAttribute("data-original-zIndex")
                                        parentNode.style.zIndex = zIndex
                                    else
                                        parentNode.style.zIndex = ""

                                parentNode = parentNode.parentNode

                        for prop in widthAttributes
                            if el.hasAttribute("data-original-" + prop)
                                value = el.getAttribute("data-original-" + prop)
                                el.removeAttribute("data-original-" + prop)
                                el.style[prop] = value
                            else
                                el.style[prop] = ""

                        el.removeAttribute("data-polyfilled")
                        return

                    polyfilled = el.hasAttribute("data-polyfilled")
                    if not polyfilled
                        el.setAttribute("data-polyfilled", "1")

                    # transform... creates a new context
                    # position fixed/z-index are applied relatively to that context
                    for prop in widthAttributes
                        if el.hasAttribute("data-original-" + prop)
                            value = el.getAttribute("data-original-" + prop)
                        else
                            value = getMatchingCssStyle(el, prop)

                            if not polyfilled and el.style[prop]
                                el.setAttribute("data-original-" + prop, value)

                        if /^\d+(?:.\d+)%$/.test(value)
                            value = parseFloat(value) * window.innerWidth / 100
                            el.style[prop] = value + "px"

                    offsetTop = 0
                    offsetLeft = 0
                    zIndex = this.backdrop_.style.zIndex

                    if CSSMatrix
                        parentNode = el.parentNode
                        while parentNode and parentNode isnt body
                            transform = getMatchingCssStyle(parentNode, "transform")
                            if transform
                                matrix = new CSSMatrix transform
                                offsetLeft -= parentNode.offsetLeft + matrix.m41
                                offsetTop -= parentNode.offsetTop + matrix.m42

                                if not polyfilled and parentNode.style
                                    parentNode.setAttribute("data-original-zIndex", parentNode.style.zIndex)
                                parentNode.style.zIndex = zIndex

                            parentNode = parentNode.parentNode

                    windowHeight = window.innerHeight
                    dialogHeight = el.clientHeight
                    el.style.position = "fixed"
                    el.style.top = "#{offsetTop + (windowHeight - dialogHeight) / 2}px"
                    el.style.left = offsetLeft + "px"

                    # this.backdrop_.style.top = offsetTop + "px"
                    # this.backdrop_.style.left = offsetLeft + "px"
                    # this.backdrop_.style.bottom = "" # offsetTop + "px"
                    # this.backdrop_.style.right = "" # offsetLeft + "px"
                    # this.backdrop_.style.width =  window.innerWidth + "px"
                    # this.backdrop_.style.height =  window.innerHeight + "px"
                    return

            if @props.onCancel
                @el.addEventListener('cancel', @props.onCancel, true)

            if @props.open
                @el.showModal()

            return

        componentWillUnmout: ->
            if @props.onCancel
                @el.removeEventListener('cancel', @props.onCancel, true)

            if @polyfill
                delete @polyfill.setOpen
                @polyfill.destroy()

            super
            return

        showModal: (options)->
            el = @el
            if options?.from
                {target, clientX, clientY} = options.from
                tx = clientX - window.innerWidth / 2
                ty = clientY - window.innerHeight / 2
                sx = target.clientWidth / (el.clientWidth or window.innerWidth)
                sy = target.clientHeight / (el.clientHeight or window.innerHeight)
                el.style[transitionJSPropertyName] = 'initial'
                el.style.opacity = 0
                @transform = el.style[transformJSPropertyName] = "translate3d( #{tx}px, #{ty}px, 0 ) scale( #{sx}, #{sy} )"

            el.showModal()

            if options?.from
                el.style[transitionJSPropertyName] = ''
                el.style[transformJSPropertyName] = ''
                el.style.opacity = 1

            if @props.onOpen
                @props.onOpen()

            return

        close: (options)->
            el = @el
            if @transform
                el.style.opacity = 0
                el.style[transformJSPropertyName] = @transform
                @transform = null
                setTimeout ->
                    el.close()
                    return
                , 250
            else
                el.close()
            return

        render: ->
            props = _.clone @props
            children = props.children

            delete props.children
            delete props.spModel
            delete props.onOpen
            delete props.onCancel

            if _.isArray children
                args = ['dialog', props].concat children
            else if children
                args = ['dialog', props, children]
            else
                args = ['dialog', props]

            @addClass props, 'mdl-dialog'
            return React.createElement.apply React, args

    Dialog.getBinding = (binding)-> binding

    Dialog
