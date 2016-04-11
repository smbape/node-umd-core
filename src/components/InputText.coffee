deps = [
    '../common'
    '../GenericUtil'
    './AbstractModelComponent'
]

freact = ({_, $}, {throttle}, AbstractModelComponent)->

    length = (value)->
        if value then value.length else 0

    class InputText extends AbstractModelComponent
        uid: 'InputText_'

        constructor: ->
            super
            # @_updateClass = throttle(100, @_updateClass, true).bind @

        componentWillMount: ->
            @props.binding?.instance = @
            @id = _.uniqueId @uid
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
            @_addClass 'input--focused', evt.target.parentNode, @classList
            return

        onBlur: (evt)=>
            @_removeClass 'input--focused', evt.target.parentNode, @classList
            return

        render:->
            props = _.clone @props

            id = props.id or @id
            {children, className, spModel, input, style, disabled} = props
            delete props.children
            delete props.className
            delete props.spModel
            delete props.input
            delete props.style

            if className
                className = @classList.join(" ") + " " + className
            else
                className = @classList.join(" ")

            wrapperProps = {disabled, className, style}

            if not input
                input = 'input'
            else if _.isArray(input)
                [input, inputProps, inputChildren] = input

            input = React.createElement input, _.extend({
                id
                className: "input__field"
                @onFocus
                @onBlur
                onInput: @_updateClass
            }, props, inputProps, {ref: 'input'}), inputChildren

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

            args.push children

            React.createElement.apply React, args

        _getInput: ->
            @refs.input

        _updateClass: =>
            el = @_getInput()

            if /^\s*$/.test (el.value or el.innerHTML)
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
            if binding._ref instanceof InputText
                instance = binding._ref
                input = instance._getInput()
                input.innerHTML or input.value

        return binding


    InputText
