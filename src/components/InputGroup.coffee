deps = [
    'umd-core/src/common'
    'umd-core/src/makeTwoWayBinbing'
]

freact = ({_, $}, makeTwoWayBinbing)->
    uid = ('InputGroup' + Math.random()).replace /\D/g, ''
    created = 0
    map = [].map

    configs =
        radio:
            get: (binding)->
                $(binding._node).find("input[type=radio]:checked").val()

            set: (binding, value)->
                $(binding._node).find("input[type=radio][value=#{value}]").prop('checked', true)

            setValue: (name)->
                (value)->
                    selected = false

                    # for correct html behaviour, every radio name must have the same name
                    $(ReactDOM.findDOMNode(this)).find('input[type=radio]').each (index, element)->
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

            set: (binding, value)->
                $(binding._node).find("input[type=checkbox][value=#{value}]").each (index, element)->
                    element.checked = true
                    return
                return

            setValue: (name)->
                (value)->
                    if Array.isArray @props.value
                        value = @props.value.map (element)->
                            '' + element
                        $(ReactDOM.findDOMNode(this)).find('input[type="checkbox"]').each (index, element)->
                            element.setAttribute 'name', name
                            if element.value in value
                                element.checked = true
                            return

                    else
                        $(ReactDOM.findDOMNode(this)).find('input[type="checkbox"]').each (index, element)->
                            element.setAttribute 'name', name
                            if element.value is value
                                element.checked = true
                            return

                    return

    class InputGroup extends React.Component
        constructor: (props)->
            ++created

            # clone because we will modify props
            props = _.clone props

            props.name = props.name or uid + created
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
            return

        render: -> `(<div {...this.props}/>)`

        componentWillUnmount: ->
            # remove every references
            for own prop of @
                delete @[prop]

            return

    # define 2 way binding behaviour
    InputGroup.getBinding = (binding, config)->
        bconf = configs[config.type]
        binding.set = bconf.set
        binding.get = bconf.get

        return binding

    return InputGroup
