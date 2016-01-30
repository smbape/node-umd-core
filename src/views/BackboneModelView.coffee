deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone'}
    '../eachSeries'
    '../ExpressionParser'
    '../patch'
]

factory = (_, $, Backbone, eachSeries, ExpressionParser)->
    hasOwn = {}.hasOwnProperty

    class BackboneView extends Backbone.View
        _parseExpression: ExpressionParser.parse
        _expressionCache: {}

        container: null
        events: null
        title: null

        constructor: (options = {})->
            @id = @id or _.uniqueId 'view_'

            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.constructor?.__super__

                    if currProto
                        @[opt] = options[opt]

            super options

        delegateEvents: ->
            super

            @$el.on 'click.delegateEvents.' + @cid, '[bb-click]', _.bind (evt)->
                # hack to prevent bubble on this specific handler
                # for triggered user action event or triggered event
                memo = evt.originalEvent or evt
                return if memo['bb-click']
                memo['bb-click'] = true

                expr = evt.currentTarget.getAttribute('bb-click')
                if !expr
                    return

                fn = @_expressionCache[expr]
                if !fn
                    fn = @_expressionCache[expr] = @_parseExpression(expr)
                
                return fn.call @, {event: evt}, window
            , @

            @$el.on 'submit.delegateEvents.' + @cid, '[bb-submit]', _.bind (evt)->
                # hack to prevent bubble on this specific handler
                # for triggered user action event or triggered event
                memo = evt.originalEvent or evt
                return if memo['bb-submit']
                memo['bb-submit'] = true

                expr = evt.currentTarget.getAttribute('bb-submit')
                if !expr
                    return

                fn = @_expressionCache[expr]
                if !fn
                    fn = @_expressionCache[expr] = @_parseExpression(expr)
                
                return fn.call @, {event: evt}, window
            , @

            return

        initialize: (options)->
            super

            overridables = [
                'template'
                'componentWillMount'
                'mount'
                'componentDidMount'
                'componentWillUnmount'
                'unmount'
                'componenDidUnmount'
            ]
            for opt in overridables
                @[opt] = options[opt] if hasOwn.call options, opt

        take: ->
            throw new Error 'View is in a rendering process' if this.$$busy
            this.$$busy = true
            return

        give: ->
            this.$$busy = false
            return

        mountTasks: ->
            [
                'componentWillMount'
                ['mount', this.container]
                'componentDidMount'
            ]

        unmountTasks: ->
            [
                'componentWillUnmount'
                'unmount'
                'componenDidUnmount'
            ]

        modelChangeTasks: ->
            this.unmountTasks(this.container).concat this.mountTasks(this.container)

        doRender: (done)->
            view = @
            view.take()
            eachSeries view, this.mountTasks(), (err)->
                view.give()
                done() if 'function' is typeof done
                return

            return

        onModelChange: (model, done)->
            @reRender done
            return

        reRender: (done)->
            view = this
            modelChangeTasks = view.modelChangeTasks(view.container)
            view.take()
            eachSeries view, modelChangeTasks, (err)->
                view.give()
                done() if 'function' is typeof done
                return
            return

        destroy: (done)->
            view = @
            return if view.destroyed
            
            view.take()

            destroyTasks = this.unmountTasks().concat ['undelegateEvents']

            eachSeries view, destroyTasks, (err)->
                view.trigger 'destroy', view
                if typeof view.$el isnt 'undefined'
                    view.$el.destroy()

                for own prop of view
                    view[prop] = null

                view.destroyed = true
                done() if 'function' is typeof done
                return

            return

        isMounted: ->
            @mounted

        # to attach delegated events, use events instead
        # here do dom manipulations that do not need mount
        # it will be faster than doing it when element is mounted
        componentWillMount: ->
            switch typeof @template
                when 'function'
                    if @model instanceof Backbone.Model
                        data = @model.toJSON()
                    else if @model instanceof Backbone.Collection and 'function' is typeof @model.attrToJSON
                        data = @model.attrToJSON()
                    xhtml = @template.call @, data
                when 'string'
                    xhtml = @template
                else
                    xhtml = ''

            @.$el.empty().html xhtml
            return

        mount: (container)->
            container.appendChild @el
            @mounted = true
            return

        # here do dom manipulations that need mount
        componentDidMount: ->
            if model = this.model
                model.on 'change', this.onModelChange, this
            return

        # undo what have been done in componentDidMount
        componentWillUnmount: ->
            if model = this.model
                model.off 'change', this.onModelChange, this

            return

        # undo what have been done in mount
        unmount: ->
            @el.parentNode.removeChild @el if @el.parentNode
            @mounted = false
            return

        # undo what have been done in componentWillMount
        componenDidUnmount: ->
