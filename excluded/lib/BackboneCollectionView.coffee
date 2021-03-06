deps = [
    '../common'
    '../models/BackboneCollection'
    './BackboneModelView'
    '../GenericUtil'
]

factory = ({_, $, Backbone}, BackboneCollection, BackboneModelView, GenericUtil)->
    hasOwn = {}.hasOwnProperty

    class BackboneCollectionView extends BackboneModelView

        constructor: (options = {})->
            @_viewAttributes = new Backbone.Model options.attributes or this.attributes

            super

            if this.model and not (this.model instanceof BackboneCollection)
                throw new Error 'model must be given and be an instanceof BackboneCollection'

            for opt in ['childTemplate', 'childrenContainer']
                if hasOwn.call options, opt
                    this[opt] = options[opt]

            this.setComparator options.comparator

        setAttribute: ->
            @_viewAttributes.set.apply @_viewAttributes, arguments

        getAttribute: (attr)->
            @_viewAttributes.get attr

        setComparator: (comparator)->
            this.detachEvents()

            if 'function' is typeof comparator
                this._model = this.model if not this._model
                this.model = this._model.getSubSet comparator: comparator
                res = true
            else if comparator is null and this._model
                this.model = this._model
                delete this._model
                res = true
            else
                res = false

            this.attachEvents()

            res

        sort: (comparator, reverse)->
            if 'string' is typeof comparator
                comparator = GenericUtil.comparators.PropertyComarator comparator

            if arguments.length is 1 and 'boolean' is typeof comparator
                reverse = comparator
                comparator = this.model.comparator

            if reverse
                comparator = GenericUtil.comparators.reverse comparator

            this.setComparator(comparator) and this.renderChildren()

        attachEvents: ->
            if this.model
                this.model.on 'add', this.onAdd, this
                this.model.on 'move', this.onMove, this
                this.model.on 'remove', this.onRemove, this
                this.model.on 'reset', this.onReset, this
                this.model.on 'switch', this.onSwitch, this
            @_viewAttributes.on 'change', this.onModelChange, this
            return

        detachEvents: ->
            @_viewAttributes.off 'change', this.onModelChange, this
            if this.model
                this.model.off 'switch', this.onSwitch, this
                this.model.off 'reset', this.onReset, this
                this.model.off 'remove', this.onRemove, this
                this.model.off 'move', this.onMove, this
                this.model.off 'add', this.onAdd, this
            return

        destroy: ->
            return if @destroyed
            this.detachEvents()
            super
            return

        renderParent: ->
            # remove node from DOM existant container
            # it is better for performance since children are only rerender is explicetely asked to
            if @_childContainer?.length > 0
                container = @_childContainer
                container[0].parentNode?.removeChild container[0]

            switch typeof @template
                when 'function'
                    data = {}

                    # Collection model attributes
                    if 'function' is typeof @model.attrToJSON
                        data.model = @model.attrToJSON()
                    else
                        data.model = _.clone @model.attributes

                    data.view = @_viewAttributes.toJSON()

                    xhtml = @template.call @, data
                when 'string'
                    xhtml = @template
                else
                    xhtml = ''

            @.$el.empty().html xhtml

            # readd removed node
            if container
                _toDestroy = @getChildrenContainer()
                container.insertBefore _toDestroy
                _toDestroy.destroy()
            else
                @_childContainer = @getChildrenContainer()

            return

        renderChildren: ->
            models = this.model.models

            # Append current elements
            # String contanation is faster with array. Common in intepreted languages such as lua
            # http://www.lua.org/pil/11.6.html
            # http://www.sitepoint.com/javascript-fast-string-concatenation/
            xhtml = []
            for model, index in models
                xhtml.push this.getChildXhtml model
                span = null
            container = this.getChildrenContainer()
            container.empty().html xhtml.join('')

            return

        componentWillMount: ->
            this.renderParent()
            this.renderChildren()
            return

        componenDidUnmount: ->
            delete @_childContainer
            return

        getChildrenContainer: ->
            if @_childContainer?.length > 0
                return @_childContainer

            if @childrenContainer
                return @$el.find @childrenContainer

            containerId = @id + '-children'

            container = @$el.find '#' + containerId
            return container if container.length > 0

            container = document.createElement 'span'
            container.id = containerId
            @el.appendChild container

            return $ container

        getChildXhtml: (model)->
            template = this.childTemplate
            if 'function' isnt typeof template
                return ''

            context =
                model: model.toJSON()
                view: @_viewAttributes.toJSON()

            if collection = this.model
                if 'function' is typeof collection.attrToJSON
                    context.collection = collection.attrToJSON()
                else
                    context.collection = _.clone collection.attributes

            template.call @, context

        onAdd: (model, collection, options)->
            container = this.getChildrenContainer()
            xhtml = this.getChildXhtml model
            element = $ xhtml

            index = options.index or this.model.indexOf model
            if typeof index isnt 'undefined' and index isnt -1
                container.insertAt index, element
            else
                container.append element
            return

        onMove: (model, collection, options)->
            {index, from} = options

            xhtml = this.getChildXhtml model

            newElement = $ xhtml
            container = this.getChildrenContainer()

            container = this.getChildrenContainer()
            oldElement = $ container[0].children[from]
            oldElement.destroy()

            if index isnt -1
                container.insertAt index, newElement
            else
                container.append newElement

            return

        onRemove: (model, collection, options)->
            index = options.index
            container = this.getChildrenContainer()
            element = $ container[0].children[index]

            element.destroy()

            return

        onReset: (collection, options)->
            @reRender()
            this.trigger 'reset', this, options
            return

        onSwitch: ->
            @reRender()
            return

        onModelChange: (model, collection, options)->
            options = collection if 'undefined' is typeof options

            # Ignore events originally comming deeper that collection child
            # for collection of collections
            return if options.level > 1

            if model is this.model
                this.renderParent()
            else if model is @_viewAttributes
                if sort = model.changed.sort
                    this.sort sort.attribute, sort.value is 'desc'
                else
                    this.renderParent()
            else
                index = this.model.indexOf model
                xhtml = this.getChildXhtml model

                container = this.getChildrenContainer()
                oldElement = $ container[0].children[index]
                oldElement.replaceWith xhtml
                oldElement.destroy()

            return
