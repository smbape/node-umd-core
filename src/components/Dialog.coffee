deps = [
    '../common'
    './AbstractModelComponent'
    '../../lib/dialogPolyfill'
]

freact = ({_}, AbstractModelComponent, dialogPolyfill)->
    dialog = document.createElement 'dialog'
    if dialog.showModal
        dialog = null
        polyfill = false
    else
        polyfill = true

    class Dialog extends AbstractModelComponent
        componentDidMount: ->
            super
            if @el.tagName is 'DIALOG' and not @el.showModal
                @polyfill = dialogPolyfill.registerDialog @el
            return

        componentWillUnmout: ->
            if @polyfill
                @polyfill.destroy()
                dialog = @dialog
                setTimeout ->
                    ReactDOM.unmountComponentAtNode dialog
                    dialog = null
                    return
                , 0
            super
            return

        showModal: ->
            if @dialogEl
                @dialogEl.el.showModal()
            else
                @el.showModal()
            return

        close: ->
            if @dialogEl
                @dialogEl.el.close()
            else
                @el.close()
            return

        render: ->
            props = _.clone @props
            children = props.children

            delete props.children
            delete props.spModel

            if _.isArray children
                args = ['dialog', props].concat children
            else if children
                args = ['dialog', props, children]
            else
                args = ['dialog', props]

            if polyfill
                if props.ignoreDialog
                    return React.createElement.apply React, args

                props.ignoreDialog = true
                args[0] = this.constructor
                element = React.createElement.apply React, args

                if not @dialog
                    @dialog = document.createElement 'span'
                    document.body.appendChild @dialog

                # 2 render in the same render process is not allowed
                setTimeout =>
                    @dialogEl = ReactDOM.render element, @dialog
                    return
                , 0

                # dummy element, the real one is hold by @dialogEl
                return `<span />`
            else
                return React.createElement.apply React, args

    Dialog.getBinding = true
    Dialog
