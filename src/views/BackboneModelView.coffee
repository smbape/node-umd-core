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
            while (reactNode = reactNode.closest('[id^=view_]')).length
                nodeID = reactNode[0].id
                if hasOwn.call componentCache, nodeID
                    component = componentCache[nodeID]
                    break

                reactNode = reactNode.parent().closest('[id^=view_]')

            if component
                return fn.call component, {event: evt}, window


    $document = $(document)
    $document.on 'click', '[data-click]', handleInlineEventScript('data-click')
    $document.on 'submit', '[data-submit]', handleInlineEventScript('data-submit')

    class BackboneView extends Backbone.View

        container: null
        events: null
        title: null

        constructor: (options = {})->
            @id = @id or _.uniqueId 'view_'
            componentCache[@id] = @

            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.constructor?.__super__

                    if currProto
                        @[opt] = options[opt]

            super options

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
                done null, view if 'function' is typeof done
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

            delete componentCache[@id]
            
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
