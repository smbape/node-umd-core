deps = [
    '../common'
    '../components/AbstractModelComponent'
]

freact = ({_, $, Backbone}, AbstractModelComponent)->
    hasOwn = {}.hasOwnProperty

    emptyObject = (obj)->
        for own prop of obj
            delete obj[prop]

        return

    class ReactModelView extends AbstractModelComponent
        uid: 'ReactModelView' + ('' + Math.random()).replace(/\D/g, '')

        constructor: (props = {})->
            @_options = _.clone props
            super
            @props.mediator?.trigger 'instance', @

        getModel: (props = @props, state = @state)->
            props.model

        # make sure to call this method,
        # otherwise, route changes will hang up
        componentDidMount: ->
            super
            @props.mediator?.trigger 'mount', @
            return

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state)]

        attachEvents: (model, attr)->
            if model
                model.on 'change', @onModelChange, @
            return

        detachEvents: (model, attr)->
            if model
                model.off 'change', @onModelChange, @
            return

        onModelChange: ->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            @_updateView()
            return

        destroy: ->
            if @destroyed
                return

            {container, mediator} = @_options

            if container
                ReactDOM.unmountComponentAtNode container

            if mediator
                mediator.trigger 'destroy', @

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

        reRender: (done)->
            @destroy()
            @doRender done
            return

        destroy: ->
            if @_component
                @_component.destroy()
                @_component = null
            return

    ReactModelView.createElement = (props)->
        return new Element this, props

    ReactModelView
