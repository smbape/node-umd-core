deps = ['../common']

freact = ({_, $})->
    uid = 'InputText' + ('' + Math.random()).replace(/\D/g, '')

    addClass = (className, el, classList)->
        if classList.indexOf(className) is -1
            classList.push className
        $(el).addClass(className)

    removeClass = (className, el, classList)->
        if ~(index = classList.indexOf(className))
            classList.splice index, 1
        $(el).removeClass(className)

    class InputText extends React.Component
        _getId: ->
            @props.id or @id

        _getInput: ->
            document.getElementById @_getId()

        componentWillMount: ->
            @props.binding?.instance = @
            @id = _.uniqueId uid
            @classList = ['input']
            return

        componentDidMount: ->
            el = @_getInput()
            if not /^\s*$/.test(el.value)
                addClass 'input--has-value', el.parentNode, @classList
            return

        componentWillUnmount: ->
            # remove every references
            for own prop of @
                delete @[prop]

            return

        onFocus: (evt)=>
            addClass 'input--focused', evt.target.parentNode, @classList
            return

        onBlur: (evt)=>
            removeClass 'input--focused', evt.target.parentNode, @classList
            if /^\s*$/.test evt.target.value
                removeClass 'input--has-value', evt.target.parentNode, @classList
            else
                addClass 'input--has-value', evt.target.parentNode, @classList
            return

        render:->
            props = _.clone @props

            id = props.id or @id
            css = props.css or 'default'
            {children, className, spModel, input, disabled} = props
            delete props.children
            delete props.className
            delete props.spModel

            if className
                className = @classList.join(" ") + " " + className
            else
                className = @classList.join(" ")

            wrapperProps = {disabled, className}

            if not input
                input = 'input'
            else if _.isArray(input)
                [input, inputProps, inputChildren] = input

            input = React.createElement input, _.extend(
                id: id
                className: "input__field"
                onFocus: @onFocus
                onBlur: @onBlur
            , props, inputProps), inputChildren

            `<span {...wrapperProps}>
                { input }
                <span className="input__bar" />
                <label className={"input__label input__label--" + css} htmlFor={id}>
                    <span className={"input__label-content input__label-content--" + css}>{props.label}</span>
                </label>
                {children}
            </span>`

    # 2 way binbing is done on input, not on this component
    InputText.getBinding = (binding, config)->

        binding.get = (binding)->
            $(binding.instance._getInput()).val()

        binding.set = (binding, value)->
            $(binding.instance._getInput()).val value
            return


        return binding


    InputText
