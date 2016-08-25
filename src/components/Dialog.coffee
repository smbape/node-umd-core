deps = [
    '../common'
    './AbstractModelComponent'
    '../../lib/dialogPolyfill'
]

freact = ({_}, AbstractModelComponent, dialogPolyfill)->

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
                @getDOMNode().addEventListener('cancel', @props.onCancel, true)

            if @props.open
                @getDOMNode().showModal()

            return

        componentWillUnmout: ->
            if @props.onCancel
                @getDOMNode().removeEventListener('cancel', @props.onCancel, true)

            if @polyfill
                delete @polyfill.setOpen
                @polyfill.destroy()

            super
            return

        showModal: ->
            @getDOMNode().showModal()
            if @props.onOpen
                @props.onOpen()
            return

        close: ->
            @getDOMNode().close()
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
