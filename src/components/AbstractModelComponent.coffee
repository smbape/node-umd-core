deps = [
    '../common'
    '../makeTwoWayBinbing'
    '!componentHandler'
]

freact = ({_, $, Backbone}, makeTwoWayBinbing, componentHandler)->
    slice = [].slice

    createElement = React.createElement
    React.createElement = (type, config)->
        args = arguments

        if config and not config.mdlIgnore and 'string' is typeof type and /(?:^|\s)mdl-/.test config.className
            # dynamic mdl component creation
            # TODO: create a hook system to allow more dynamic components creation
            args = slice.call arguments
            config = _.defaults {tagName: type, mdlIgnore: true}, config
            type = args[0] = MdlComponent
            args[1] = config

        element = createElement.apply React, args
        binding = makeTwoWayBinbing element, type, config
        element.props.binding = binding

        if not appConfig.isProduction
            Object.freeze element.props
            Object.freeze element

        return element

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + ('' + Math.random()).replace(/\D/g, '')

        constructor: ->
            super
            @inline = new Backbone.Model()
            @initialize()

        initialize: ->

        getModel: (props = @props)->
            props.spModel?[0]

        getModelAttr: (props = @props)->
            props.spModel?[1]

        componentWillMount: ->

        componentDidMount: ->
            @el = ReactDOM.findDOMNode @
            @$el = $ @el

            if @_bindings
                for binding in @_bindings
                    binding.instance = @

            @attachEvents.apply @, @getEventArgs()

            return

        componentWillReceiveProps: (nextProps)->

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = @shouldUpdate or !_.isEqual(@state, nextState) or !_.isEqual(@props, nextProps)
            @shouldUpdate = false

            shouldUpdateEvent = @shouldUpdateEvent nextProps, nextState
            shouldUpdate or shouldUpdateEvent

        shouldUpdateEvent: (nextProps, nextState)->
            if 'function' is typeof @getNewEventArgs
                args = @getNewEventArgs nextProps, nextState
            else
                args = @getEventArgs nextProps, nextState
            oldArgs = @getEventArgs()
            if _.isEqual(args, oldArgs)
                return false

            @detachEvents.apply @, oldArgs
            @attachEvents.apply @, args
            return true

        componentWillUpdate: (nextProps, nextState)->

        componentDidUpdate: (prevProps, prevState)->

        componentWillUnmount: ->
            if @_bindings
                for binding in @_bindings
                    binding._detach binding

            @detachEvents.apply @, @getEventArgs()

            # remove every references
            for own prop of @
                if prop isnt 'refs'
                    delete @[prop]

            @destroyed = true
            return

        getEventArgs: (props = @props, state = @state)->
            [@getModel(props, state), @getModelAttr(props, state)]

        attachEvents: (model, attr)->
            if model
                model.on "change:#{attr}", @onModelChange, @
            return

        detachEvents: (model, attr)->
            if model
                model.off "change:#{attr}", @onModelChange, @
            return

        onModelChange: ->
            options = arguments[arguments.length - 1]
            if options.bubble > 0
                # ignore bubbled events
                return

            @_updateOwner()
            return

        _updateView: ->
            @shouldUpdate = true
            if @_reactInternalInstance
                state = {}
                state[@uid] = new Date().getTime()
                @setState state
            return

        _updateOwner: ->
            @shouldUpdate = true

            if @_reactInternalInstance
                state = {}
                state[@uid] = new Date().getTime()
                if owner = @_reactInternalInstance._currentElement._owner?._instance
                    owner.setState state
                else
                    @setState state
            return

    class MdlComponent extends AbstractModelComponent
        componentDidMount:->
            super
            componentHandler.upgradeElement @el

            return

        componentWillUnmount: ->
            componentHandler.downgradeElements [@el]
            super
            return

        render:->
            React.createElement @props.tagName or 'span', @props

    AbstractModelComponent.MdlComponent = MdlComponent

    # avoid circular reference
    makeTwoWayBinbing.init AbstractModelComponent

    AbstractModelComponent