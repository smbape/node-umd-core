deps = [
    'umd-core/src/common'
]

freact = ({_, Backbone, EventEmitter})->
    hasOwn = {}.hasOwnProperty

    class ReactView extends EventEmitter
        constructor: (options = {})->
            for opt in ['model', 'componentSpec']
                this[opt] = options[opt] if hasOwn.call options, opt

            if this.model and not (this.model instanceof Backbone.Model) and not (this.model instanceof Backbone.Collection)
                throw new Error 'model must be an instance of Backbone.Model or  Backbone.Collection'

            proto = @constructor.prototype
            for own opt of options
                if opt.charAt(0) isnt '_' and (hasOwn.call(proto, opt) or 'undefined' isnt typeof proto[opt])
                    @[opt] = options[opt]

        componentMixin: ->
            shouldComponentUpdate: (nextProps, nextState)->
                shouldUpdate = if typeof @shouldUpdate is 'undefined'
                    true
                else
                    @shouldUpdate
                @shouldUpdate = false
                shouldUpdate

            componentWillMount: ->
                @attachEvents()
                return

            componentWillUnmount: ->
                @detachEvents()
                return

            # make sure to call this method,
            # otherwise, route changes will hang up
            componentDidMount: ->
                @props.view.emit 'render', @props.view if @props.view
                return

            getModelState: ->
                @props.model?.toJSON() or null

            trackModelChange: ->
                # make sure state updates view
                @shouldUpdate = true
                @setState {stuff: new Date().getTime()}
                return

            attachEvents: ->
                @props.model?.on 'change', @trackModelChange, @
                @props.model?.on 'reset', @trackModelChange, @
                return

            detachEvents: ->
                @props.model?.off 'change', @trackModelChange, @
                @props.model?.off 'reset', @trackModelChange, @
                return

        createComponent: ->
            React.createClass _.defaults {}, @componentSpec(), @componentMixin()

        destroy: ->
            ReactDOM.unmountComponentAtNode @container
            for own prop of @
                delete @[prop]
            return

        render: (@container, done)->
            @once 'render', done if 'function' is typeof done
            Component = @createComponent()
            ReactDOM.render React.createElement(Component, { model: @model, view: @ }), @container
            return
