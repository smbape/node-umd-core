deps = [
    './common'
]

freact = ({_, $})->
    hasOwn = {}.hasOwnProperty
    _expressionCache = {}
    uid = 'makeTwoWayBinbing' + ('' + Math.random()).replace(/\D/g, '')
    AbstractModelComponent = null

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    _makeTwoWayBinbing = (type, config, element)->
        if not config or not (this instanceof AbstractModelComponent)
            return

        {spModel: model, validate, forceUpdate} = config

        if 'string' is typeof model
            property = model
            model = @inline
            element.props.spModel = [model, property]
        else if _.isArray model
            if _.isArray model[0]
                models = []
                events = []
                for args in model
                    models.push args[0]
                    events.push args[1]
                model = models
            else
                [model, property, events] = model
        else
            return

        if 'function' is typeof type and not type.getBinding
            return

        if not _.isObject(model) or 'function' isnt typeof model.on or 'function' isnt typeof model.off
            return

        if 'string' is typeof property
            if 'string' is typeof events and events.length > 0
                events = "change:#{property}" + events
            else
                events = "change:#{property}"
        else
            property = null

        if 'string' isnt typeof events
            return

        # TODO : Find a way to avoid creation and destruction in __ref

        # until creation, instance is not known
        # no other choice than add first, then remove it
        if not @_bindings
            @_bindings = []

        if not @_bindexists
            @_bindexists = {}

        binding =
            id: _.uniqueId 'bd'
            events: events
            owner: this
            model: model
            validate: validate
            forceUpdate: forceUpdate

            _attach: (binding)->
                if _.isArray binding.model
                    for i in [0...binding.model.length] by 1
                        _model = binding.model[i]
                        _events = binding.events[i]
                    _model.on _events, binding._onModelChange, binding.owner
                else
                    binding.model.on binding.events, binding._onModelChange, binding.owner
                return

            _detach: (binding)->
                if _.isArray binding.model
                    for i in [0...binding.model.length] by 1
                        _model = binding.model[i]
                        _events = binding.events[i]
                    _model.off _events, binding._onModelChange, binding.owner
                else
                    binding.model.off binding.events, binding._onModelChange, binding.owner

                emptyObject binding
                return

            _onModelChange: (model, value, options)->
                if binding._ref instanceof AbstractModelComponent
                    binding._ref.shouldUpdate = true
                    if binding.forceUpdate
                        binding._ref._updateView()

                state = {}
                state[uid] = new Date()

                # https://facebook.github.io/react/docs/two-way-binding-helpers.html
                # set state on owner to trigger rerender
                if binding.owner
                    if binding.owner instanceof AbstractModelComponent
                        binding.owner.shouldUpdate = true
                    binding.owner.setState state
                return

            __ref: (ref)->
                return if not ref
                node = ReactDOM.findDOMNode(ref)

                if ref instanceof AbstractModelComponent
                    existing = ref.props.binding.id
                else if not (existing = ref.binding)
                    existing = ref.binding = binding.id

                if (existing = @_bindexists[existing]) and existing isnt binding
                    index = binding.index

                    if existing.model isnt binding.model or existing.events isnt binding.events
                        # model changed
                        index = existing.index
                        @_bindings.splice index, 1
                        existing._detach existing
                        emptyObject existing

                    else
                        @_bindings.splice index, 1
                        binding._detach binding
                        emptyObject binding

                        # onChange is always a new function, make sure it uses the correct binding object
                        binding = existing

                    for i in [index...@_bindings.length] by 1
                        @_bindings[i].index--
                    return

                @_bindexists[binding.id] = binding

                binding._ref = ref
                binding._node = node
                binding._attach binding
                return

        binding.index = @_bindings.length
        @_bindings.push binding

        if type is 'input' and config.type is 'checkbox'
            binding.get = (binding, evt)->
                $(evt.target).prop('checked')

        else if 'function' is typeof type and 'function' is typeof type.getBinding
            binding = type.getBinding binding, config
        else
            binding.get = (binding, evt)->
                $(evt.target).val()

        binding.__ref = binding.__ref.bind binding.owner

        props = element.props

        if property and ('string' isnt typeof type or type in ['input', 'select', 'textarea'])
            # to ease testing
            props['data-bind-attr'] = property

            # TODO : Find a way to avoid new on change function
            __onChange = (evt)->
                binding.model.set property, binding.get(binding, evt), {dom: true, validate: binding.validate}
                return

            # make sure created native component will have the correct initial value
            value = model.attributes[property]
            if typeof value in ['boolean', 'number', 'string']
                if type is 'input' and config.type is 'checkbox'
                    props.checked = value
                else
                    props.value = value
            else
                delete props.value

            if 'function' is typeof props.onChange
                onChange = props.onChange
                props.onChange = ->
                    __onChange.apply undefined, arguments
                    onChange.apply undefined, arguments
                    return
            else
                props.onChange = __onChange

        switch typeof element.ref
            when 'function'
                ref = element.ref
                __ref = binding.__ref
                element.ref = ->
                    __ref.apply undefined, arguments
                    ref.apply undefined, arguments
                    return
            when 'string'
                ref = this.setRef element.ref
                __ref = binding.__ref
                element.ref = ->
                    __ref.apply undefined, arguments
                    ref.apply undefined, arguments
                    return
            when 'undefined'
                element.ref = binding.__ref

        return binding

    makeTwoWayBinbing = (element, type, config, toSetElement)->
        if element?._owner?._instance
            _makeTwoWayBinbing.call(element._owner._instance, type, config, toSetElement or element)

    makeTwoWayBinbing.init = (Component)->
        AbstractModelComponent = Component

    makeTwoWayBinbing
