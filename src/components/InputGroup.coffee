deps = [
    'umd-core/src/common'
    'umd-core/src/makeTwoWayBinbing'
    './AbstractModelComponent'
]

freact = ({_, $}, makeTwoWayBinbing, AbstractModelComponent)->
    map = [].map

    configs =
        radio:
            get: (binding)->
                $(binding._node).find("input[type=radio]:checked").val()

            setValue: (name)->
                (value)->
                    selected = false

                    # for correct html behaviour, every radio name must have the same name
                    @$el.find('input[type=radio]').each (index, element)->
                        element.setAttribute 'name', name
                        if not selected and element.value is value
                            selected = true
                            element.checked = true
                        return

                    return

        checkbox:
            get: (binding)->
                map.call $(binding._node).find("input[type=checkbox]:checked"), (element)->
                    element.value

            setValue: (name)->
                (value)->
                    if Array.isArray @props.value
                        value = @props.value.map (element)->
                            '' + element
                        @$el.find('input[type="checkbox"]').each (index, element)->
                            element.setAttribute 'name', name
                            if element.value in value
                                element.checked = true
                            else
                                element.checked = false
                            return

                    else
                        @$el.find('input[type="checkbox"]').each (index, element)->
                            element.setAttribute 'name', name
                            if element.value is value
                                element.checked = true
                            return

                    return

    class InputGroup extends AbstractModelComponent
        uid: 'InputGroup' + ('' + Math.random()).replace(/\D/g, '')

        constructor: (props)->

            # clone because we will modify props
            props = _.clone props

            props.name = props.name or _.uniqueId @uid
            if props.type is 'radio'
                @type = props.type
            else
                @type = 'checkbox'

            # type prop is only for us
            delete props.type

            @setValue = configs[@type].setValue(props.name)
            super(props)

        componentDidMount: ->
            @setValue @props.value
            super()
            return

        componentDidUpdate: (prevProps, prevState)->
            @setValue @props.value
            super(prevProps, prevState)
            return

        render: -> `(<div {...this.props}/>)`

    # define 2 way binding behaviour
    InputGroup.getBinding = (binding, config)->
        bconf = configs[config.type]
        binding.get = bconf.get

        return binding

    return InputGroup
