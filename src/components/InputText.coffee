deps = [
    '../common'
    '../GenericUtil'
    './AbstractModelComponent'
]

freact = ({_, $}, {throttle, mergeFunctions}, AbstractModelComponent)->
    {deepCloneElement} = AbstractModelComponent

    length = (value)->
        if value then value.length else 0

    getInputValue = (input)->
        switch input.nodeName
            when 'INPUT'
                if input.type is 'checkbox'
                    return input.checked

                return input.value
            
            when 'TEXTAREA', 'SELECT', 'OPTION', 'BUTTON', 'DATALIST', 'OUTPUT'
                return input.value
            else
                return input.innerHTML


    class InputText extends AbstractModelComponent
        uid: 'InputText_'

        componentWillMount: ->
            @props.binding?.instance = @
            @classList = ['input']
            super

            return

        componentDidMount: ->
            super()
            @_updateClass()
            return

        componentDidUpdate: (prevProps, prevState)->
            super(prevProps, prevState)
            @_updateClass()
            return

        onFocus: (evt)=>
            @_addClass 'input--focused', @$el, @classList
            return

        onBlur: (evt)=>
            @_removeClass 'input--focused', @$el, @classList
            return

        render:->
            props = _.clone @props

            id = props.id or @id
            {children, className, spModel, input, style, disabled, onFocus, onBlur, onChange} = props

            for prop in ['children', 'className', 'spModel', 'input', 'style', 'disabled', 'onFocus', 'onBlur', 'onChange']
                delete props[prop]

            if className
                className = @classList.join(" ") + " " + className
            else
                className = @classList.join(" ")

            wrapperProps = {disabled, className, style}

            if React.isValidElement(input)
                {onBlur: onInputBlur, onFocus: onInputFocus, onChange: onInputChange, className: classNameInput} = input.props
                if not classNameInput
                    classNameInput = 'input__field'

                input = deepCloneElement input, {
                    id
                    className: classNameInput
                    ref: 'input'
                    onFocus: mergeFunctions @onFocus, onFocus, onInputFocus
                    onBlur: mergeFunctions @onBlur, onBlur, onInputBlur
                    onChange: mergeFunctions @_updateClass, onChange, onInputChange
                    spModel: null
                    label: null
                }
            else if _.isArray(input)
                [type, inputProps, inputChildren] = input
                {onBlur: onInputBlur, onFocus: onInputFocus, onChange: onInputChange, className: classNameInput} = inputProps
                if not classNameInput
                    classNameInput = 'input__field'

                inputProps = _.extend {
                    id
                    className: classNameInput
                }, props, inputProps, {
                    ref: 'input'
                    onFocus: mergeFunctions @onFocus, onFocus, onInputFocus
                    onBlur: mergeFunctions @onBlur, onBlur, onInputBlur
                    onChange: mergeFunctions @_updateClass, onChange, onInputChange
                    spModel: null
                    label: null
                }

                args = [type, inputProps]
                if _.isArray inputChildren
                    args.push.apply args, inputChildren
                else
                    args.push inputChildren

                input = React.createElement.apply React, args
            else
                switch typeof input
                    when 'string'
                        type = input
                        inputType = 'text'
                        if not props.defaultValue
                            value = ''
                    when 'function'
                        type = input
                    else
                        type = 'input'
                        inputType = 'text'
                        if not props.defaultValue
                            value = ''

                inputProps = _.extend {
                    id
                    className: "input__field"
                    type: inputType
                    value: value
                }, props, {
                    ref: 'input'
                    onFocus: mergeFunctions @onFocus, onFocus, onInputFocus
                    onBlur: mergeFunctions @onBlur, onBlur, onInputBlur
                    onChange: mergeFunctions @_updateClass, onChange, onInputChange
                    spModel: null
                    label: null
                }

                input = React.createElement type, inputProps

            if props.label
                label = `<label className={"input__label"} htmlFor={id}>
                    <span className={"input__label-content"}>{props.label}</span>
                </label>`

            args = ['span', wrapperProps, input]

            if props.charCount
                args.push `<div className="char-count">{length(spModel[0].get(spModel[1]))}/{props.charCount}</div>`
            else
                args.push undefined

            args.push `<span className="input__bar" />`

            if label
                args.push label
            else
                args.push undefined

            if _.isArray children
                args.push.apply args, children
            else
                args.push children

            React.createElement.apply React, args

        _getInput: ->
            input = @refs.input
            if typeof input.getInput is 'function'
                return input.getInput()
            
            return input

        _updateClass: =>
            el = @_getInput()

            if /^\s*$/.test getInputValue el
                @_removeClass 'input--has-value', @$el, @classList
            else
                @_addClass 'input--has-value', @$el, @classList
            return

        _addClass: (className, $el, classList)->
            if classList.indexOf(className) is -1
                classList.push className
            $el.addClass(className)

        _removeClass: (className, $el, classList)->
            if ~(index = classList.indexOf(className))
                classList.splice index, 1
            $el.removeClass(className)

    # 2 way binbing is done on input, not on this component
    InputText.getBinding = (binding, config)->

        binding.get = (binding)->
            if binding._ref instanceof InputText
                instance = binding._ref
                input = instance._getInput()
                return getInputValue input
        return binding


    InputText
