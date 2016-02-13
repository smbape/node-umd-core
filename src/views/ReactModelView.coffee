deps = [
    '../common'
    '../makeTwoWayBinbing'
]

freact = ({_, $, Backbone}, makeTwoWayBinbing)->
    hasOwn = {}.hasOwnProperty
    uid = 'ReactModelView' + ('' + Math.random()).replace(/\D/g, '')

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    class ReactModelView extends React.Component
        constructor: (props = {})->
            @_options = _.clone props
            super

            @inline = new Backbone.Model()
            @checkModel()
            @props.mediator?.trigger 'instance', @

        checkModel: ->
            if @props.model and not (@props.model instanceof Backbone.Model) and not (@props.model instanceof Backbone.Collection)
                throw new Error 'model must be an instance of Backbone.Model or Backbone.Collection'
            return true

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = @shouldUpdate or !_.isEqual(@state, nextState) or !_.isEqual(@props, nextProps)

            if @getModel(@state, @props) isnt @getModel(nextState, nextProps)
                @detachEvents()
                shouldUpdate = true

            @shouldUpdate = false
            shouldUpdate

        componentWillMount: ->
            @props.binding?.instance = @
            return

        # make sure to call this method,
        # otherwise, route changes will hang up
        componentDidMount: ->
            @attachEvents()
            @props.mediator?.trigger 'mount', @
            return

        componentWillUnmount: ->
            # @props.mediator?.trigger 'unmount', @
            if @_bindings
                for binding in @_bindings
                    binding._detach binding

            @detachEvents()
            return

        componentWillReceiveProps: (nextProps)->

        componentWillUpdate: ->
            @attachEvents()
            return

        _updateView: ->
            # make sure state updates view
            @shouldUpdate = true
            if @_reactInternalInstance
                state = {}
                state[uid] = new Date().getTime()
                @setState state
            return

        onModelChange: ->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            @_updateView()
            return

        getModel: (props = @props, state = @state)->
            props.model

        attachEvents: ->
            return false if @_attached
            @getModel()?.on 'change', @onModelChange, @
            @_attached = true
            return true

        detachEvents: ->
            return false if not @_attached
            @getModel()?.off 'change', @onModelChange, @
            @_attached = false
            return true

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

        getFilter: (value, isValue)->
            if not isValue
                value = @inline.get value

            switch typeof value
                when 'string'
                    regexp = new RegExp value.replace(/([\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}])/g, '\\$1'), 'i'
                    fn = (model)->
                        for own prop of model.attributes
                            if regexp.test(model.attributes[prop]) 
                                return true

                        return false
                    fn.value = value
                    fn
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
        binding = makeTwoWayBinbing element, type, config
        element.props.binding = binding

        # # DEV ONLY
        Object.freeze element.props
        Object.freeze element

        return element

    ReactModelView.createElement = (props)->
        return new Element this, props

    ReactModelView
