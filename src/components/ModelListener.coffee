deps = [
    '../common'
    '../views/ReactModelView'
]

freact = ({_, i18n}, ReactModelView)->
    class ModelListener extends ReactModelView
        tagName: 'span'

        _onModelEvent: ->
            callback = @props.onEvent
            @_children = callback.apply @, arguments
            @_updateView()
            return

        _getEventConfig: (props = @props, state = @state)->
            if (callback = props.onEvent) and
            (events = props.events) and
            (model = @getModel(props, state)) and
            'function' is typeof callback and
            'string' is typeof events
                return [model, events, @_onModelEvent]

        attachEvents: ->
            return false if @_attached
            if config = @_getEventConfig()
                [model, events, callback] = config
                model.on events, callback, @
            @_attached = true
            return true

        detachEvents: ->
            return false if not @_attached
            if config = @_getEventConfig()
                [model, events, callback] = config
                model.off events, callback, @
            @_attached = false
            return true

        render:->
            React.createElement @tagName, @props, @_children
