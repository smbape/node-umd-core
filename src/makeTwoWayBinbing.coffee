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

        {spModel: model, validate, forceUpdate, onlyThis} = config

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

        if not events
            return

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
            onlyThis: onlyThis

            _attach: (binding)->
                if _.isArray binding.model
                    for i in [0...binding.model.length] by 1
                        _model = binding.model[i]
                        _events = binding.events[i]
                    _model.on _events, binding._onModelChange, binding
                else
                    binding.model.on binding.events, binding._onModelChange, binding

                binding.owner._bindexists[binding.id] = binding
                return

            _detach: (binding)->
                if _.isArray binding.model
                    for i in [0...binding.model.length] by 1
                        _model = binding.model[i]
                        _events = binding.events[i]
                    _model.off _events, binding._onModelChange, binding
                else
                    binding.model.off binding.events, binding._onModelChange, binding

                delete binding.owner._bindexists[binding.id]
                emptyObject binding
                return

            _onModelChange: (model, value, options)->
                binding = @
                {_ref, forceUpdate, onlyThis, owner} = binding

                if _ref instanceof AbstractModelComponent
                    _ref.shouldUpdate = true
                    if forceUpdate or onlyThis
                        _ref._updateView()

                if onlyThis
                    return

                state = {}
                state[uid] = new Date()

                if owner
                    owner._updateView()
                return

            __ref: (ref)->
                return if not ref

                # TODO: Find a way to make it part of componentDidMount/componentDidUpdate

                node = ReactDOM.findDOMNode(ref)
                binding = @
                owner = binding.owner

                if not (existing = ref.binding)
                    existing = ref.binding = binding.id

                if (prevBinding = owner._bindexists[existing]) and prevBinding isnt binding
                    index = binding.index

                    if prevBinding.model isnt binding.model or prevBinding.events isnt binding.events
                        # model changed
                        index = prevBinding.index
                        owner._bindings.splice index, 1
                        prevBinding._detach prevBinding

                    else
                        owner._bindings.splice index, 1
                        emptyObject binding

                        # onChange is always a new function, make sure it uses the correct binding object
                        binding = prevBinding

                    for i in [index...owner._bindings.length] by 1
                        owner._bindings[i].index--
                    return

                binding._ref = ref
                binding._node = node
                binding._attach binding
                return

        if property
            switch typeof type
                when 'function'
                    if 'function' is typeof type.getBinding
                        valueProp = 'value'
                        binding = type.getBinding binding, config
                when 'string'
                    switch type
                        when 'input'
                            if config.type is 'checkbox'
                                valueProp = 'checked'
                                binding.get = (binding, evt)-> evt.target.checked
                            else
                                valueProp = 'value'
                                binding.get = (binding, evt)-> evt.target.value
                        when 'textarea', 'select', 'option', 'button', 'datalist', 'output'
                            valueProp = 'value'
                            binding.get = (binding, evt)-> evt.target.value
                        else
                            if config.contentEditable in ["true", true]
                                valueProp = 'innerHTML'
                                binding.get = (binding, evt)-> evt.target.innerHTML

        binding.index = @_bindings.length
        binding.__ref = binding.__ref.bind binding
        @_bindings.push binding

        if valueProp
            props = element.props

            # to ease testing
            props['data-bind-attr'] = property

            # TODO : Find a way to avoid new props.onChange function
            # if model+events didn't change

            __onChange = (evt)->
                binding.model.set property, binding.get(binding, evt), {dom: true, validate: binding.validate}
                return

            # make sure created native component will have the correct initial value
            value = model.attributes[property]
            if typeof value in ['boolean', 'number', 'string']
                if valueProp is 'innerHTML'
                    props.dangerouslySetInnerHTML = __html: value
                else
                    props[valueProp] = value
            else
                if valueProp is 'innerHTML'
                    delete props.dangerouslySetInnerHTML
                else
                    delete props[valueProp]

            onChangeEvent = binding.onChangeEvent

            if not onChangeEvent
                if type is 'input'
                    onInput = config.type isnt 'checkbox'
                else
                    onInput = type is 'textarea' or config.contentEditable in ["true", true]

                if onInput
                    onChangeEvent = 'onInput'
                else
                    onChangeEvent = 'onChange'

                binding.onChangeEvent = onChangeEvent

            if 'function' is typeof props[onChangeEvent]
                onChange = props[onChangeEvent]
                props[onChangeEvent] = ->
                    __onChange.apply undefined, arguments
                    onChange.apply undefined, arguments
                    return
            else
                props[onChangeEvent] = __onChange

        # TODO : Find a way to avoid new element.ref function
        # if model+events didn't change
        switch typeof element.ref
            when 'function'
                ref = element.ref
                __ref = binding.__ref
                element.ref = ->
                    __ref.apply undefined, arguments
                    ref.apply undefined, arguments
                    return
            when 'string'
                # TODO : find a way to deal with string ref
                console.error 'string ref is not yet supported with 2 way binding'
                # ref = this.setRef element.ref
                # __ref = binding.__ref
                # element.ref = ->
                #     __ref.apply undefined, arguments
                #     ref.apply undefined, arguments
                #     return
            when 'undefined'
                element.ref = binding.__ref
            when 'object'
                if element.ref is null
                    element.ref = binding.__ref

        return binding

    makeTwoWayBinbing = (element, type, config, toSetElement)->
        if element?._owner?._instance
            _makeTwoWayBinbing.call(element._owner._instance, type, config, toSetElement or element)

    makeTwoWayBinbing.init = (Component)->
        AbstractModelComponent = Component

    makeTwoWayBinbing
