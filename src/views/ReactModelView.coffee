deps = [
    'umd-core/src/common'
    '../ExpressionParser'
    '../../lib/acorn'
    '!escodegen'
]

freact = ({_, $, Backbone, EventEmitter}, ExpressionParser, acorn, escodegen)->
    hasOwn = {}.hasOwnProperty

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    componentCache = {}
    _parseExpression = ExpressionParser.parse
    _expressionCache = {}
    _bindingExpressionCache = {}

    do ->
        delegateEvents = [
            'blur'
            'change'
            'click'
            'drag'
            'drop'
            'focus'
            'input'
            'load'
            'mouseenter'
            'mouseleave'
            'mousemove'
            'propertychange'
            'reset'
            'scroll'
            'submit'

            'abort'
            'canplay'
            'canplaythrough'
            'durationchange'
            'emptied'
            'encrypted'
            'ended'
            'error'
            'loadeddata'
            'loadedmetadata'
            'loadstart'
            'pause'
            'play'
            'playing'
            'progress'
            'ratechange'
            'seeked'
            'seeking'
            'stalled'
            'suspend'
            'timeupdate'
            'volumechange'
            'waiting'
        ]

        $document = $(document)
        delegate = (type)->
            attr = 'data-' + type
            $document.on type, "[#{attr}]", (evt)->
                expr = evt.currentTarget.getAttribute(attr)
                if !expr
                    return

                fn = _expressionCache[expr]
                if !fn
                    fn = _expressionCache[expr] = _parseExpression(expr)

                reactNode = $(evt.currentTarget)
                while (reactNode = reactNode.closest('[data-reactid]')).length
                    nodeID = reactNode[0].getAttribute('data-reactid')
                    if hasOwn.call componentCache, nodeID
                        component = componentCache[nodeID]
                        break

                    reactNode = reactNode.parent().closest('[data-reactid]')

                if component
                    return fn.call component, {event: evt}, window

            return


        for evt in delegateEvents
            delegate evt

        return

    class ReactModelView extends React.Component
        container: null
        model: null

        constructor: (options = {})->
            @id = _.uniqueId 'view_'
            options = @_options = _.clone options
            this._bindings = []
            this._bindexists = {}

            proto = @constructor.prototype

            if proto is ReactModelView.prototype
                for own opt of options
                    if opt.charAt(0) isnt '_'
                        if hasOwn.call(proto, opt)
                            @[opt] = options[opt]
                            delete options[opt]
            else
                for own opt of options
                    if opt.charAt(0) isnt '_'
                        currProto = proto
                        while currProto and not hasOwn.call(currProto, opt)
                            currProto = currProto.constructor?.__super__

                        if currProto
                            @[opt] = options[opt]
                            delete options[opt]

            super

            if not (@model instanceof Backbone.Model) and not (@model instanceof Backbone.Collection)
                throw new Error 'model must be an instance of Backbone.Model or Backbone.Collection'

            
            @props.mediator?.trigger 'instance', @

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = if typeof @shouldUpdate is 'undefined'
                true
            else
                @shouldUpdate
            @shouldUpdate = false
            shouldUpdate

        # make sure to call this method,
        # otherwise, route changes will hang up
        componentDidMount: ->
            @attachEvents()
            _rootNodeID = @_reactInternalInstance._rootNodeID
            componentCache[_rootNodeID] = @
            @props.mediator?.trigger 'mount', @
            return

        componentWillUnmount: ->
            # @props.mediator?.trigger 'unmount', @
            for binding in @_bindings
                binding.detach binding._ref, binding._node
                binding.model.off binding.event, binding._onModelChange, binding.context
                emptyObject binding

            _rootNodeID = @_reactInternalInstance._rootNodeID
            delete componentCache[_rootNodeID]
            @detachEvents()
            return

        _updateView: ->
            # make sure state updates view
            @shouldUpdate = true
            @setState {time: new Date().getTime()}
            return

        onModelChange: ->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            @_updateView()
            return

        attachEvents: ->
            @detachEvents()
            @model.on 'change', @onModelChange, @
            return

        detachEvents: ->
            @model.off 'change', @onModelChange, @
            return

        destroy: ->
            if @destroyed
                return

            if @container
                ReactDOM.unmountComponentAtNode @container

            @props.mediator?.trigger 'destroy', @

            for own prop of @
                delete @[prop]

            @destroyed = true
            return

    _doRender = (element, {mediator, container})->
        (done)->
            if 'function' is typeof done
                mediator.once 'mount', ->
                    done null, element
                    return

            mediator.once 'instance', (component)->
                element._component = component
                return

            mediator.once 'destroy', ->
                mediator.off 'mount'
                emptyObject element
                emptyObject mediator
                return

            ReactDOM.render element._internal, container
            return

    class Element
        constructor: (Component, props)->
            {mediator, container} = props
            mediator = _.extend {}, Backbone.Events
            @props = props = _.extend {mediator}, props

            if not container
                throw new Error 'container must be defined'

            @_internal = React.createElement Component, props

        doRender: (done)->
            element = @
            {container, mediator} = @props
            if 'function' is typeof done
                mediator.once 'mount', ->
                    done null, element
                    return

            mediator.once 'instance', (component)->
                element._component = component
                return

            mediator.once 'destroy', ->
                mediator.off 'mount'
                emptyObject element
                emptyObject mediator
                return

            ReactDOM.render element._internal, container
            return

        destroy: ->
            if @_component
                @_component.destroy()
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

    createElement = React.createElement
    React.createElement = (type, config, children)->
        element = createElement.apply React, arguments

        if config?.modelValue and element?._owner?._instance and element._owner._instance.props?.model
            switch type
                when 'input', 'textarea'
                    ((expr, props)->
                        if not hasOwn.call _bindingExpressionCache, expr
                            _bindingExpressionCache[expr] = parseBinding expr

                        if fn = _bindingExpressionCache[expr]
                            try
                                [model, property] = fn.call(this)
                            catch ex
                                console.error ex, ex.stack
                                return
                        else
                            return

                        binding =
                            event: "change:#{property}"
                            context: this
                            model: model

                            attach: (ref, node)->
                            detach: (ref, node)->

                            set: (ref, node, value)->
                                $(node).val value
                                return

                            get: (ref, node)->
                                $(node).val()

                            _onModelChange: (model, value, options)->
                                return if options.dom
                                binding.set binding._ref, binding._node, model.get(property)
                                return

                            _onChange: (evt)->
                                binding.model.set(property, binding.get(binding._ref, binding._node), {dom: true})
                                return

                            __ref: (ref)->
                                return if not ref

                                if this._bindexists[ref] and this._bindexists[ref] isnt binding
                                    if ~(index = this._bindings.indexOf binding)
                                        this._bindings.splice index, 1
                                        emptyObject binding

                                    # onChange is always a new function, make it use the correct binding
                                    binding = this._bindexists[ref]
                                    return

                                this._bindexists[ref] = binding
                                node = ReactDOM.findDOMNode(ref)

                                binding._ref = ref
                                binding._node = node
                                binding.attach binding._ref, binding._node
                                binding.model.on binding.event, binding._onModelChange, binding.context
                                return

                        binding.__ref = _.bind binding.__ref, binding.context
                        for method in ['attach', 'detach', 'set', 'get']
                            if 'function' is typeof props[method]
                                binding[method] = props[method]
                            binding[method] = _.bind binding[method], binding.context

                        props.value = binding.model.attributes[property]
                        props.onChange = binding._onChange
                        element.ref = binding.__ref
                        this._bindings.push binding
                        return
                    ).call(element._owner._instance, config.modelValue, element.props)

        # DEV ONLY
        Object.freeze element.props
        Object.freeze element

        return element

    ReactModelView.createElement = (props)->
        return new Element this, props

    ReactModelView
