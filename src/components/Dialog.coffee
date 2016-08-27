deps = [
    '../common'
    './AbstractModelComponent'
    '../../lib/dialogPolyfill'
]

freact = ({_}, AbstractModelComponent, dialogPolyfill)->

    testElementStyle = document.createElement('div').style
    transformJSPropertyName = if 'transform' of testElementStyle then 'transform' else 'webkitTransform'
    transitionJSPropertyName = if 'transition' of testElementStyle then 'transition' else 'webkitTransition'
    testElementStyle = null

    class Dialog extends AbstractModelComponent
        componentDidMount: ->
            super
            el = @el
            if el.tagName is 'DIALOG' and not el.showModal
                polyfill = @polyfill = dialogPolyfill.registerDialog el
                setOpen = polyfill.setOpen
                polyfill.setOpen = (value)->
                    setOpen.call polyfill, value
                    if value
                        windowHeight = window.innerHeight
                        dialogHeight = el.clientHeight
                        el.style.position = 'fixed'
                        el.style.top = "#{(windowHeight - dialogHeight) / 2}px"
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
            if options
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

        _createDialog: (args)->
            @addClass args[1], 'mdl-dialog'
            return React.createElement.apply React, args

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

            return @_createDialog args

    Dialog.getBinding = (binding)-> binding

    Dialog
