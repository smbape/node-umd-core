deps = [
    '../common'
    './InputText'
]

freact = ({_}, InputText)->
    class InputWithError extends React.Component
        componentWillMount: ->
            {spModel: [model, attr]} = @props
            model.on 'vstate:' + attr, @_updateView, @

            return

        componentWillReceiveProps: (nextProps)->
            {spModel: [model, attr]} = nextProps
            {spModel: [oldModel, oldAttr]} = @props

            if model isnt oldModel or attr isnt oldAttr
                oldModel.off 'vstate:' + oldAttr, @_updateView, @
                model.on 'vstate:' + attr, @_updateView, @

            return

        componentWillUnmount: ->
            {spModel: [model, attr]} = @props
            model.off 'vstate:' + attr, @_updateView, @

            # remove every references
            for own prop of @
                delete @[prop]

            return

        _updateView: ->
            {spModel: [model, attr]} = @props
            if model.invalidAttrs[attr]
                @className = 'input--invalid'
                @isValid = false
            else
                @className = ''
                @isValid = true

            if @_reactInternalInstance
                @setState {time: new Date().getTime()}
            return

        render: ->
            props = _.clone @props
            {spModel: [model, attr], children} = props
            delete props.children

            className = @className
            if props.className
                props.className += ' ' + className
            else
                props.className = className

            `<InputText {...props}>
                <div className="error-messages">
                    {children}
                    <div spRepeat="(message, index) in model.invalidAttrs[attr]" className="error-message" key={index}>{message}</div>
                </div>
            </InputText>`

    # a proxy component
    InputWithError.getBinding = false

    InputWithError
