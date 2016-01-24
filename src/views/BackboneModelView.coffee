deps = [
    {amd: 'lodash', common: '!_', node: 'lodash'}
    {amd: 'jquery', common: '!jQuery'}
    {amd: 'backbone', common: '!Backbone'}
    '../eachSeries'
    '../patch'
]

factory = (_, $, Backbone, eachSeries)->
    hasOwn = {}.hasOwnProperty

    class BackboneView extends Backbone.View
        events: {}

        constructor: (options)->
            @id = @id or _.uniqueId 'view_'

            proto = @constructor.prototype

            for own opt of options
                if opt.charAt(0) isnt '_'
                    currProto = proto
                    while currProto and not hasOwn.call(currProto, opt)
                        currProto = currProto.prototype

                    if currProto
                        @[opt] = options[opt]

            super

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

        render: (container, done)->
            view = @
            view.container = container

            if 'function' isnt typeof view.render
                done new Error 'view must implement a render method'
                return

            if 'function' isnt typeof view.mount
                done new Error 'view must implement a mount method'
                return

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
            
            view.take()

            destroyTasks = this.unmountTasks().concat ['undelegateEvents']

            eachSeries view, destroyTasks, (err)->
                view.trigger 'destroy', view
                if typeof view.$el isnt 'undefined'
                    view.$el.destroy()

                for own prop of view
                    view[prop] = null

                done() if 'function' is typeof done
                return

            return

        isMounted: ->
            @mounted

        # to attach delegated events, use events instead
        # here do dom manipulations that do not need mount
        # it will be faster than doing it when element is mounted
        componentWillMount: ->
            if typeof @template is 'function'
                if @model instanceof Backbone.Model
                    data = @model.toJSON()
                else if @model instanceof Backbone.Collection and 'function' is typeof @model.attrToJSON
                    data = @model.attrToJSON()
                xhtml = @template data
            else if 'string' is typeof @template
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
