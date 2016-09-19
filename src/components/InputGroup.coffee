deps = [
    'umd-core/src/common'
    'umd-core/src/makeTwoWayBinbing'
    './AbstractModelComponent'
]

freact = ({_, $}, makeTwoWayBinbing, AbstractModelComponent)->
    map = [].map

    class InputGroup extends AbstractModelComponent
        uid: 'InputGroup' + ('' + Math.random()).replace(/\D/g, '')

        configs:
            tristate:
                get: (binding)->
                    value = $(binding._node).find("input[type=radio]:checked").val()
                    switch value
                        when '1', 'true', 'on', 'yes', 't'
                            return true
                        when '0', 'false', 'off', 'no', 'f'
                            return false
                        else
                            return null

                setValue: (name)->
                    (value)->
                        selected = false

                        # for correct html behaviour, every radio name must have the same name
                        @$el.find('input[type=radio]').each (index, element)->
                            element.setAttribute 'name', name
                            return if selected
                            switch element.value
                                when '1', 'true', 'on', 'yes', 't'
                                    element.checked = value is true
                                when '0', 'false', 'off', 'no', 'f'
                                    element.checked = value is false
                                else
                                    element.checked = value in [null, undefined]
                            return

                        return

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

        initialize: (props)->
            props = @props

            name = props.name or _.uniqueId(@uid + '_')

            if props.type in ['radio', 'tristate', 'checkbox']
                type = props.type
            else
                type = 'checkbox'

            @setValue = @configs[type].setValue(name)

            @state = { name, type }
            return

        componentDidMount: ->
            super
            @setValue @props.value
            return

        componentDidUpdate: (prevProps, prevState)->
            super
            @setValue @props.value
            return

        render: ->
            props = _.clone @props

            for prop in ['type', 'getValue', 'setValue']
                delete props[prop]

            React.createElement 'div', props

    # define 2 way binding behaviour
    InputGroup.getBinding = (binding, config)->
        bconf = this.prototype.configs[config.type]
        binding.get = bconf.get
        binding.getValue = config.getValue

        return binding

    return InputGroup
