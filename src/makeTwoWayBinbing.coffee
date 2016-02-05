deps = [
    './common'
    '../lib/acorn'
    '../lib/escodegen'
]

freact = ({_, $}, acorn, escodegen)->
    hasOwn = {}.hasOwnProperty
    _expressionCache = {}
    uid = ('makeTwoWayBinbing' + Math.random()).replace /\D/g, ''

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    parseBinding = (expr)->
        try
            ast = acorn.parse expr
            if ast.body.length is 1 and ast.body[0].type is 'ExpressionStatement' and ast.body[0].expression.type is 'MemberExpression'
                {object, property} = ast.body[0].expression

                property.end -= property.start
                property.start = 0

                object = escodegen.generate object
                property = escodegen.generate property

                ### jshint -W054 ###
                return new Function "return [#{object}, '#{property}'];"
        catch ex
            console.error ex, ex.stack
            return

    _makeTwoWayBinbing = (type, config, element)->
        if not config
            return

        {spModel: model, spModelAttr: property, spModelLink: expr} = config

        if model
            if 'string' is typeof model
                property = model
                model = @inline
            else if 'string' isnt typeof property
                return
        else if expr
            if not hasOwn.call _expressionCache, expr
                _expressionCache[expr] = parseBinding expr

            if fn = _expressionCache[expr]
                try
                    [model, property] = fn.call(this)
                catch ex
                    console.error ex, ex.stack
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
            context: this
            model: model
            property: property
            value: model.attributes[property]

            _attach: (binding)->
                binding.model.on binding.event, binding._onModelChange, binding.context
                return

            _detach: (binding)->
                binding.model.off binding.event, binding._onModelChange, binding.context
                emptyObject binding
                return

            _onModelChange: (model, value, options)->
                if options.dom
                    state = {}
                    state[uid] = new Date()
                    binding.context.setState state
                    return
                binding.set binding, value
                return

            __onChange: (evt)->
                binding.model.set(property, binding.get(binding), {dom: true})
                return

            __ref: (ref)->
                return if not ref
                node = ReactDOM.findDOMNode(ref)

                if not node.reactex
                    node.reactex = binding.id

                if (existing = @_bindexists[node.reactex]) and existing isnt binding
                    index = binding.index

                    if existing.model isnt binding.model
                        # BAD, model changed
                        @_bindings.splice index, 1
                        existing._detach existing

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

            binding.set = (binding, value)->
                $(binding._node).prop('checked', value)
                return
        else if 'function' is typeof type and 'function' is typeof type.getBinding
            binding = type.getBinding binding, config
        else
            binding.get = (binding)->
                $(binding._node).val()

            binding.set = (binding, value)->
                $(binding._node).val value
                return

        binding.__ref = _.bind binding.__ref, binding.context

        props = element.props
        for method in ['get', 'set']
            if 'function' is typeof props[method + 'Value']
                binding[method] = props[method + 'Value']
            binding[method] = _.bind binding[method], binding.context

        if 'undefined' isnt typeof binding.value
            props.value = binding.value

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
