deps = [
    '../common'
    './AbstractModelComponent'
    './InputText'
]

freact = ({_}, AbstractModelComponent, InputText)->

    class InputWithError extends AbstractModelComponent
        uid: 'InputWithError' + ('' + Math.random()).replace(/\D/g, '')

        _onVStateChange: ->
            [model, attr] = @getEventArgs()

            if model.invalidAttrs[attr]
                @className = 'input--invalid'
                @isValid = false
            else
                @className = ''
                @isValid = true

            @_updateView()
            return

        getEventArgs: (props = @props, state = @state)->
            props.spModel

        attachEvents: (model, attr)->
            events = "vstate:#{attr}"
            model.on events, @_onVStateChange, @
            return

        detachEvents: (model, attr)->
            events = "vstate:#{attr}"
            model.off events, @_onVStateChange, @
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
