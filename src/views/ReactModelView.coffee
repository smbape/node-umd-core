deps = [
    'umd-core/src/common'
    '../ExpressionParser'
]

freact = ({_, $, Backbone, EventEmitter}, ExpressionParser)->
    hasOwn = {}.hasOwnProperty

    componentCache = {}
    _parseExpression = ExpressionParser.parse
    _expressionCache = {}

    handleInlineEventScript = (attr)->
        (evt)->
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


    $document = $(document)
    $document.on 'click', '[data-click]', handleInlineEventScript('data-click')
    $document.on 'submit', '[data-submit]', handleInlineEventScript('data-submit')

    class ReactModelView extends React.Component
        container: null
        model: null

        constructor: (options = {})->
            @id = _.uniqueId 'view_'
            options = @_options = _.clone options

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

            if @container
                @$container = $ @container

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

            # if @_reactInternalInstance and container = ReactDOM.findDOMNode @
            #     container = $ container

            #     container.on 'click.delegateEvents.' + @model.cid, '[data-click]', _.bind (evt)->
            #         # hack to prevent bubble on this specific handler
            #         # for triggered user action event or triggered event
            #         memo = evt.originalEvent or evt
            #         return if memo['data-click']
            #         memo['data-click'] = true

            #         expr = evt.currentTarget.getAttribute('data-click')
            #         if !expr
            #             return

            #         fn = @_expressionCache[expr]
            #         if !fn
            #             fn = @_expressionCache[expr] = @_parseExpression(expr)
                    
            #         return fn.call @, {event: evt}, window
            #     , @

            #     container.on 'submit.delegateEvents.' + @model.cid, '[data-submit]', _.bind (evt)->
            #         # hack to prevent bubble on this specific handler
            #         # for triggered user action event or triggered event
            #         memo = evt.originalEvent or evt
            #         return if memo['data-submit']
            #         memo['data-submit'] = true

            #         expr = evt.currentTarget.getAttribute('data-submit')
            #         if !expr
            #             return

            #         fn = @_expressionCache[expr]
            #         if !fn
            #             fn = @_expressionCache[expr] = @_parseExpression(expr)
                    
            #         return fn.call @, {event: evt}, window
            #     , @

            return

        detachEvents: ->
            # if @_reactInternalInstance and container = ReactDOM.findDOMNode @
            #     $(container).off '.delegateEvents.' + @model.cid

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

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

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

    ReactModelView.createElement = (props)->
        return new Element this, props

    ReactModelView
