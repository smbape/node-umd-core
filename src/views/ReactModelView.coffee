deps = [
    'umd-core/src/common'
    '../ExpressionParser'
]

freact = ({_, $, Backbone}, ExpressionParser)->
    hasOwn = {}.hasOwnProperty

    class ReactModelView extends React.Component
        title: null
        container: null
        done: null

        _parseExpression: ExpressionParser.parse
        _expressionCache: {}

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

            if not (@props.model instanceof Backbone.Model) and not (@props.model instanceof Backbone.Collection)
                throw new Error 'model must be an instance of Backbone.Model or Backbone.Collection'

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

            if 'function' is typeof @done
                @done null, @
                delete @done
            return

        componentWillUnmount: ->
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
            @props.model.on 'change', @onModelChange, @

            if @_reactInternalInstance and container = ReactDOM.findDOMNode @
                container = $ container

                container.on 'click.delegateEvents.' + @props.model.cid, '[data-click]', _.bind (evt)->
                    # hack to prevent bubble on this specific handler
                    # for triggered user action event or triggered event
                    memo = evt.originalEvent or evt
                    return if memo['data-click']
                    memo['data-click'] = true

                    expr = evt.currentTarget.getAttribute('data-click')
                    if !expr
                        return

                    fn = @_expressionCache[expr]
                    if !fn
                        fn = @_expressionCache[expr] = @_parseExpression(expr)
                    
                    return fn.call @, {event: evt}, window
                , @

                container.on 'submit.delegateEvents.' + @props.model.cid, '[data-submit]', _.bind (evt)->
                    # hack to prevent bubble on this specific handler
                    # for triggered user action event or triggered event
                    memo = evt.originalEvent or evt
                    return if memo['data-submit']
                    memo['data-submit'] = true

                    expr = evt.currentTarget.getAttribute('data-submit')
                    if !expr
                        return

                    fn = @_expressionCache[expr]
                    if !fn
                        fn = @_expressionCache[expr] = @_parseExpression(expr)
                    
                    return fn.call @, {event: evt}, window
                , @

            return

        detachEvents: ->
            if @_reactInternalInstance and container = ReactDOM.findDOMNode @
                $(container).off '.delegateEvents.' + @props.model.cid

            @props.model.off 'change', @onModelChange, @
            return

        destroy: ->
            if @destroyed
                return

            if @container
                ReactDOM.unmountComponentAtNode @container

            if @props.owner
                @props.owner.destroy()

            for own prop of @
                delete @[prop]

            @destroyed = true
            return

        doRender: (done)->
            # BAD: find a better way
            element = React.createElement this.constructor, _.defaults {done, owner: this}, @_options
            ReactDOM.render element, @container
            return
