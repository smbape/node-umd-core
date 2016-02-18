deps = [
    '../common'
    './AbstractModelComponent'
    './InputText'
]

freact = ({_}, AbstractModelComponent, InputText)->

    class InputWithError extends AbstractModelComponent
        uid: 'InputWithError' + ('' + Math.random()).replace(/\D/g, '')

        onModelChange: ->
            model = @getModel()
            attr = @getModelAttr()

            if model.invalidAttrs[attr]
                @className = 'input--invalid'
                @isValid = false
            else
                @className = ''
                @isValid = true

            super
            return

        attachEvents: (model, attr)->
            events = "change:#{attr} vstate:#{attr}"
            model.on events, @_updateOwner, @
            return

        detachEvents: (model, attr)->
            events = "change:#{attr} vstate:#{attr}"
            model.off events, @_updateOwner, @
            return

        render: ->
            props = _.clone @props
            {spModel: [model, attr], children} = props
            delete props.children

            if className = @className
                if props.className
                    props.className += ' ' + className
                else
                    props.className = className

            args = [InputText, props]
            if _.isArray children
                args.push.apply args, children
            else
                args.push children

            args.push `<div className="error-messages">
                <div spRepeat="(message, index) in model.invalidAttrs[attr]" className="error-message" key={index}>{message}</div>
            </div>`

            React.createElement.apply React, args

    # a proxy component
    InputWithError.getBinding = false

    InputWithError
