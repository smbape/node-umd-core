deps = [
    '../common'
    '../ExpressionParser'
    '../makeTwoWayBinbing'
]

freact = ({_, $, Backbone}, ExpressionParser, makeTwoWayBinbing)->
    hasOwn = {}.hasOwnProperty

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    componentCache = {}
    _parseExpression = ExpressionParser.parse
    _expressionCache = {}

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

    isDeclaredProperty = (currProto, prop, stopPrototype)->
        while currProto and not hasOwn.call(currProto, prop)
            if currProto is stopPrototype
                currProto = undefined
            else if currProto.constructor?.__super__
                currProto = currProto.constructor.__super__
            else if currProto.constructor.prototype is currProto
                # backup original constructor
                proto = currProto
                ctor = proto.constructor

                # expose parent constructor
                delete currProto.constructor
                currProto = currProto.constructor?.prototype

                # restore constructor
                proto.constructor = ctor
            else
                currProto = undefined

        currProto

    class ReactModelView extends React.Component
        model: null

        constructor: (options = {})->
            @id = _.uniqueId 'view_'
            options = @_options = _.clone options
            proto = @constructor.prototype
            stopPrototype = ReactModelView.prototype
            for own opt of options
                if opt.charAt(0) isnt '_'
                    if isDeclaredProperty proto, opt, stopPrototype
                        @[opt] = options[opt]
                        delete options[opt]

            super

            @inline = new Backbone.Model()
            if @model and not (@model instanceof Backbone.Model) and not (@model instanceof Backbone.Collection)
                throw new Error 'model must be an instance of Backbone.Model or Backbone.Collection'

            
            @props.mediator?.trigger 'instance', @

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = if typeof @shouldUpdate is 'undefined'
                true
            else
                @shouldUpdate or !_.isEqual this.state, nextState
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
            if @_bindings
                for binding in @_bindings
                    binding._detach binding

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
            @model?.on 'change', @onModelChange, @
            return

        detachEvents: ->
            @model?.off 'change', @onModelChange, @
            return

        destroy: ->
            if @destroyed
                return

            if container = @_options.container
                ReactDOM.unmountComponentAtNode container

            @props.mediator?.trigger 'destroy', @

            for own prop of @
                delete @[prop]

            @destroyed = true
            return

        getFilter: (value)->
            value = @inline.get value
            switch typeof value
                when 'string'
                    value = new RegExp value.replace(/[\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}]/g, '\\'), 'i'
                    (model)->
                        for own prop of model.attributes
                            if value.test(model.attributes[prop]) 
                                return true

                        return false
                when 'function'
                    value
                else
                    -> true

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

        reRender: ->
            @_component._updateView()
            return

        destroy: ->
            if @_component
                @_component.destroy()
            return

    createElement = React.createElement
    React.createElement = (type, config)->
        element = createElement.apply React, arguments
        makeTwoWayBinbing element, type, config

        # # DEV ONLY
        # Object.freeze element.props
        # Object.freeze element

        return element

    ReactModelView.createElement = (props)->
        return new Element this, props

    ReactModelView
