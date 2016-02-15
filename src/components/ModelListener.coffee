deps = [
    '../common'
    '../views/ReactModelView'
]

freact = ({_}, ReactModelView)->
    class ModelListener extends ReactModelView
        componentWillMount: ->
            if @props.init isnt false
                callback = @props.onEvent
                @_children = callback.call @
            super
            return

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state), props.events, props.onEvent]

        attachEvents: (model, events, eventCallback)->
            if model
                model.on events, @_onModelEvent, @
            return

        detachEvents: (model, events, eventCallback)->
            if model
                model.off events, @_onModelEvent, @
            return

        _onModelEvent: ->
            callback = @props.onEvent
            @_children = callback.apply @, arguments
            @_updateView()
            return

        render:->
            if @props.bare
                @_children or null
            else
                React.createElement @props.tagName or 'span', @props, @_children
