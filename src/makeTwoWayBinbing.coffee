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

        {spModel: model, validate} = config

        if 'string' is typeof model
            property = model
            model = @inline
            element.props.spModel = [model, property]
        else if _.isArray model
            [model, property] = model
        else
            return

        if 'function' is typeof type and not type.getBinding
            return

        if not _.isObject(model) or not property or 'function' isnt typeof model.on or 'function' isnt typeof model.off
            return

        # until creation, instance is not known
        # no other choice than add first, then remove it
        if not @_bindings
            @_bindings = []

        if not @_bindexists
            @_bindexists = {}

        binding =
            id: _.uniqueId 'bd'
            event: "change:#{property}"
            owner: this
            model: model
            property: property
            value: model.attributes[property]
            validate: validate

            _attach: (binding)->
                binding.model.on binding.event, binding._onModelChange, binding.owner
                return

            _detach: (binding)->
                binding.model.off binding.event, binding._onModelChange, binding.owner
                emptyObject binding
                return

            _onModelChange: (model, value, options)->
                state = {}
                state[uid] = new Date()

                # https://facebook.github.io/react/docs/two-way-binding-helpers.html
                # set state on owner to trigger rerender
                binding.owner.setState state
                return

            __onChange: (evt)->
                binding.model.set property, binding.get(binding), {dom: true, validate: binding.validate}
                return

            __ref: (ref)->
                return if not ref
                node = ReactDOM.findDOMNode(ref)

                if not node.reactex
                    node.reactex = binding.id

                if (existing = @_bindexists[node.reactex]) and existing isnt binding
                    index = binding.index

                    if existing.model isnt binding.model
                        # model changed
                        index = existing.index
                        @_bindings.splice index, 1
                        existing._detach existing
                        emptyObject existing

                    else
                        @_bindings.splice index, 1
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
            binding.get = (binding)->
                $(binding._node).prop('checked')

        else if 'function' is typeof type and 'function' is typeof type.getBinding
            binding = type.getBinding binding, config
        else
            binding.get = (binding)->
                $(binding._node).val()

        binding.__ref = _.bind binding.__ref, binding.owner

        props = element.props

        # to ease testing
        props['data-bind-attr'] = property

        # make sure created native component will have the correct initial value
        if 'undefined' isnt typeof binding.value
            props.value = binding.value
        else
            delete props.value

        if 'function' is typeof props.onChange
            onChange = props.onChange
            __onChange = binding.__onChange
            props.onChange = (evt)->
                __onChange.call undefined, evt
                onChange.call undefined, evt
        else
            props.onChange = binding.__onChange

        if 'function' is typeof element.ref
            ref = element.ref
            __ref = binding.__ref
            element.ref = (evt)->
                __ref.call undefined, evt
                ref.call undefined, evt
        else
            element.ref = binding.__ref

        return binding

    makeTwoWayBinbing = (element, type, config, toSetElement)->
        if element?._owner?._instance
            _makeTwoWayBinbing.call(element._owner._instance, type, config, toSetElement or element)

    makeTwoWayBinbing.init = (Component)->
        AbstractModelComponent = Component

    makeTwoWayBinbing
