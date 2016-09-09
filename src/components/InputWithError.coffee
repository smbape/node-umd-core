deps = [
    '../common'
    './AbstractModelComponent'
    './InputText'
]

freact = ({_}, AbstractModelComponent, InputText)->

    class InputWithError extends AbstractModelComponent
        uid: 'InputWithError' + ('' + Math.random()).replace(/\D/g, '')

        _onVStateChange: ->
            {spModel: [model, attr]} = @props

            if model.invalidAttrs?[attr]
                @className = 'input--invalid'
                @isValid = false
            else
                @className = ''
                @isValid = true

            @_updateView()
            return

        getEventArgs: (props = @props, state = @state)->
            {spModel: [model, attr], deferred} = props
            if deferred then [model] else [model, attr]

        attachEvents: (model, attr)->
            events = if attr then "vstate:#{attr}" else 'vstate'
            model.on events, @_onVStateChange, @
            return

        detachEvents: (model, attr)->
            events = if attr then "vstate:#{attr}" else 'vstate'
            model.off events, @_onVStateChange, @
            return

        render: ->
            props = _.clone @props
            {spModel: [model, attr], children, deferred} = props
            delete props.children
            delete props.deferred

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

            if (not deferred or @isValid is false) and model.invalidAttrs?[attr]
                errors = `<div spRepeat="(message, index) in model.invalidAttrs[attr]" className="error-message" key={index}>{message}</div>`

            args.push `<div className="error-messages">
                {errors}
            </div>`

            React.createElement.apply React, args

    # a proxy component
    InputWithError.getBinding = false

    InputWithError
