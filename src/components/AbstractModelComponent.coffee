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

        # # # DEV ONLY
        # Object.freeze element.props
        # Object.freeze element

        return element

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + ('' + Math.random()).replace(/\D/g, '')

        constructor: ->
            super
            @inline = new Backbone.Model()

        getModel: (props = @props)->
            props.spModel?[0]

        getModelAttr: (props = @props)->
            props.spModel?[1]

        componentWillMount: ->

        componentDidMount: ->
            @props.binding?.instance = @
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

        componentWillUpdate: ->

        componentDidUpdate: ->

        componentWillUnmount: ->
            if @_bindings
                for binding in @_bindings
                    binding._detach binding

            @detachEvents.apply @, @getEventArgs()

            # remove every references
            for own prop of @
                delete @[prop]

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

        _updateOwner: ->
            @shouldUpdate = true

            if @_reactInternalInstance
                owner = @_reactInternalInstance._currentElement._owner._instance
                state = {}
                state[@uid] = new Date().getTime()
                owner.setState state
            return

    class MdlComponent extends AbstractModelComponent
        componentDidMount:->
            super
            el = ReactDOM.findDOMNode @
            componentHandler.upgradeElement el

            return

        componentWillUnmount: ->
            el = ReactDOM.findDOMNode @
            componentHandler.downgradeElements [el]
            super
            return

        render:->
            React.createElement @props.tagName or 'span', @props, @props.children

    AbstractModelComponent.MdlComponent = MdlComponent

    # avoid circular reference
    makeTwoWayBinbing.init AbstractModelComponent

    AbstractModelComponent