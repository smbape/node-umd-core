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
            this._viewAttributes = new Backbone.Model options.attributes or this.attributes

            super

            if this.model and not (this.model instanceof BackboneCollection)
                throw new Error 'model must be given and be an instanceof BackboneCollection'

            for opt in ['childTemplate', 'childrenContainer']
                if hasOwn.call options, opt
                    this[opt] = options[opt]

            this.setComparator options.comparator

        setAttribute: ->
            switch arguments.length
                when 1
                    this._viewAttributes.set arguments[0]
                when 2
                    this._viewAttributes.set arguments[0], arguments[1]
                else
                    this._viewAttributes.set arguments[0], arguments[1], arguments[2]
        getAttribute: (attr)->
            this._viewAttributes.get attr

        attachEvents: ->
            this.model.on 'add', this.onAdd, this
            this.model.on 'remove', this.onRemove, this
            this.model.on 'reset', this.onReset, this
            this.model.on 'change', this.onChange, this
            this.model.on 'switch', this.onSwitch, this
            this._viewAttributes.on 'change', this.onChange, this
            return

        detachEvents: ->
            this._viewAttributes.off 'change', this.onChange, this
            this.model.off 'switch', this.onSwitch, this
            this.model.off 'change', this.onChange, this
            this.model.off 'reset', this.onReset, this
            this.model.off 'remove', this.onRemove, this
            this.model.off 'add', this.onAdd, this
            return

        # initUI: ->
        #     @.$el.on 'click', '[data-set]', this.updateViewAttributes
        #     return
        # destroyUI: ->
        #     @.$el.off 'click', '[data-set]', this.updateViewAttributes
        #     return

        # updateViewAttributes: (evt)=>
        #     target = $ evt.currentTarget

        #     evt.preventDefault()
        #     evt.stopPropagation()
        #     evt.stopImmediatePropagation()

        #     value = target.attr('data-value')
        #     if value
        #         try
        #             value = JSON.parse value
        #         catch ex
        #     else
        #         value = target.val()
        #     attr = target.attr 'data-set'
        #     this._viewAttributes.set attr, value
        #     return

        destroy: ->
            this.detachEvents()
            super
            return

        renderParent: ->
            # remove node from DOM existant container
            # it is better for performance since children are only rerender is explicetely asked to
            container = this.getChildrenContainer()
            if container.length > 0
                container[0].parentNode.removeChild container[0]

            if typeof this.template is 'function'
                data = {}

                # Collection model attributes
                if 'function' is typeof this.model.attrToJSON
                    data.model = this.model.attrToJSON()
                else
                    data.model = _.clone this.model.attributes

                data.view = this._viewAttributes.toJSON()

                xhtml = this.template data
            else if 'string' is typeof @template
                xhtml = @template
            else
                xhtml = ''

            @.$el.empty().html xhtml

            # readd removed node
            if container.length > 0
                _toDestroy = this.getChildrenContainer()
                container.insertBefore _toDestroy
                _toDestroy.destroy()

            return

        renderChildren: ->
            models = this.model.models

            # Append current elements
            # String contanation is faster with array. Common in intepreted languages such as lua
            # http://www.lua.org/pil/11.6.html
            # http://www.sitepoint.com/javascript-fast-string-concatenation/
            xhtml = []
            for model in models
                xhtml[xhtml.length] = this.getChildXhtml model
            container = this.getChildrenContainer()
            container.empty().html xhtml.join('')
            return

        componentWillMount: ->
            this.renderParent()
            this.renderChildren()
            return

        getChildrenContainer: ->
            if this.childrenContainer
                return this.$el.find this.childrenContainer

            containerId = @id + '-children'

            container = this.$el.find '#' + containerId
            return container if container.length > 0

            container = document.createElement 'span'
            container.id = containerId
            this.el.appendChild container

            return $ container

        getChildXhtml: (model)->
            template = this.childTemplate
            if 'function' isnt typeof template
                return ''

            context =
                model: model.toJSON()
                view: this._viewAttributes.toJSON()

            collection = model.collection
            if collection
                if 'function' is typeof collection.attrToJSON
                    context.collection = collection.attrToJSON()
                else
                    context.collection = _.clone collection.attributes

            template context

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

        onAdd: (model)->
            index = this.model.indexOf model
            container = this.getChildrenContainer()
            xhtml = this.getChildXhtml model
            element = $ xhtml
            container.insertAt element, index
            return element

        onRemove: (model, collection, options)->
            index = options.index
            container = this.getChildrenContainer()
            children = container.children()
            element = children.eq index
            element.destroy()
            return

        onReset: (model)->
            container = this.getChildrenContainer()
            container.empty()
            this.trigger 'reset'
            return

        onChange: (model)->
            if model is this.model
                this.renderParent()
            else if model is this._viewAttributes
                if sort = model.changed.sort
                    this.sort sort.attribute, sort.value is 'desc'
                else
                    this.renderParent()
            else
                index = this.model.indexOf model
                container = this.getChildrenContainer()
                xhtml = this.getChildXhtml model
                children = container.children()
                element = children.eq index
                element.replaceWith xhtml
                element.destroy()

            this.trigger 'change'
            return

        onSwitch: ->
            this.render(this.container)
            return
