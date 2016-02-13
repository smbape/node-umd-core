deps = [
    '../common'
    './AbstractModelComponent'
]

freact = ({_, $}, AbstractModelComponent)->

    class InputText extends AbstractModelComponent
        uid: 'InputText' + ('' + Math.random()).replace(/\D/g, '')

        componentWillMount: ->
            @props.binding?.instance = @
            @id = _.uniqueId @uid
            @classList = ['input']

            super()

            return

        componentDidMount: ->
            @_updateClass @_getInput()
            return

        componentDidUpdate: ->
            @_updateClass @_getInput()
            return

        onFocus: (evt)=>
            @_addClass 'input--focused', evt.target.parentNode, @classList
            return

        onBlur: (evt)=>
            @_removeClass 'input--focused', evt.target.parentNode, @classList
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

            if props.label
                label = `<label className={"input__label input__label--" + css} htmlFor={id}>
                    <span className={"input__label-content input__label-content--" + css}>{props.label}</span>
                </label>`
            else
                label = ''

            `<span {...wrapperProps}>
                { input }
                <span className="input__bar" />
                {label}
                {children}
            </span>`

        _getId: ->
            @props.id or @id

        _getInput: ->
            document.getElementById @_getId()

        _updateClass: (el)->
            if /^\s*$/.test el.value
                @_removeClass 'input--has-value', el.parentNode, @classList
            else
                @_addClass 'input--has-value', el.parentNode, @classList
            return

        _addClass: (className, el, classList)->
            if classList.indexOf(className) is -1
                classList.push className
            $(el).addClass(className)

        _removeClass: (className, el, classList)->
            if ~(index = classList.indexOf(className))
                classList.splice index, 1
            $(el).removeClass(className)

    # 2 way binbing is done on input, not on this component
    InputText.getBinding = (binding, config)->

        binding.get = (binding)->
            $(binding.instance._getInput()).val()

        binding.set = (binding, value)->
            $(binding.instance._getInput()).val value
            return


        return binding


    InputText
