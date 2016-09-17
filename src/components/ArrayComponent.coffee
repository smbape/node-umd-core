deps = [
    '../common'
    './AbstractModelComponent'
]

freact = ({_, $, Backbone}, AbstractModelComponent)->
    hasOwn = Object::hasOwnProperty

    compareAttr = (attr, coeff, a, b)->
        if a[attr] > b[attr]
            coeff
        else if a[attr] < b[attr]
            -coeff
        else
            0

    byAttribute = (attr, reverse)->
        coeff = if reverse then -1 else 1
        compareAttr.bind(null, attr, coeff)

    class ArrayComponent extends AbstractModelComponent
        getFilter: (query)->
            switch typeof query
                when 'string'
                    query = query.trim()
                    if query.length is 0
                        return null

                    @filterCache = {} if not @filterCache
                    if hasOwn.call @filterCache, query
                        return @filterCache[query]

                    regexp = new RegExp query.replace(/([\\\/\^\$\.\|\?\*\+\(\)\[\]\{\}])/g, '\\$1'), 'i'
                    fn = (attributes)->
                        for own prop of attributes
                            if regexp.test(attributes[prop])
                                return true

                        return false

                    @filterCache[query] = fn
                when 'function'
                    query
                else
                    null

        getComparator: (comparator, reverse)->
            switch typeof comparator
                when 'string'
                    byAttribute comparator, reverse
                when 'function'
                    comparator
                else
                    null

        componentWillUpdate: (nextProps, nextState)->
            {
                collection
                filter
                order
                reverse
                limit
                offset
                childNode
            } = @_initState @props, @state

            {
                collection: nextCollection
                filter: nextFilter
                order: nextOrder
                reverse: nextReverse
                limit: nextLimit
                offset: nextOffset
                childNode: nextChildNode
            } = @_initState nextProps, nextState

            if collection isnt nextCollection
                delete @_childNodeList
            else if filter isnt nextFilter
                delete @_childNodeList
            else if order isnt nextOrder
                ordered = @_setOrderedArray @_filtered, nextOrder, nextReverse
                @_setNodeList ordered, nextLimit, nextOffset, nextChildNode
            else if reverse isnt nextReverse
                ordered = @_ordered = @_ordered.reverse()
                @_setNodeList ordered, nextLimit, nextOffset, nextChildNode
            else if limit isnt nextLimit or offset isnt nextOffset or childNode isnt nextChildNode
                @_setNodeList @_ordered, nextLimit, nextOffset, nextChildNode

            return

        _initState: (props, state)->
            {
                collection
                filter
                order
                reverse
                limit
                offset
                childNode
            } = props
            reverse = !!reverse

            {
                collection
                filter
                order
                reverse
                limit
                offset
                childNode
            }

        _setOrderedArray: (filtered, order, reverse)->
            @_ordered = filtered.sort @getComparator order, reverse

        _setNodeList: (ordered, limit, start, childNode)->
            len = ordered.length
            if limit > 0
                if not (start > 0)
                    start = 0

                finish = limit + start

                if finish > len
                    finish = len
            else
                start = 0
                finish = len

            @_childNodeList = list = []

            index = 0
            for i in [start...finish] by 1
                model = ordered[i]
                list[index] = childNode model, index, ordered
                index++
            list

        childNodeList: ->
            if @_childNodeList
                return @_childNodeList

            @_childNodeList = []

            {collection, filter, order, reverse, limit, offset, childNode} = @_initState @props,  @state
            return @_childNodeList if not collection

            @_filtered = _.filter collection, @getFilter(filter)
            ordered = @_setOrderedArray @_filtered, order, reverse
            @_setNodeList ordered, limit, offset, childNode

        _getProps: ->
            props = _.clone @props
            for key in ['collection', 'filter', 'order', 'reverse', 'limit', 'offset', 'childNode']
                delete props[key]
            props

        render: ->
            props = @_getProps()
            children  = props.children
            delete props.children

            childNodeList = @childNodeList()

            tagName = props.tagName or 'div'
            delete props.tagName

            if childNodeList and childNodeList.length > 0
                React.createElement tagName, props, childNodeList
            else
                args = [tagName, props, undefined]
                if _.isArray children
                    args.push.apply args, children
                else
                    args.push children

                React.createElement.apply React, args

    ArrayComponent.getBinding = (binding)->
        binding.get = ->
            if binding._ref instanceof ArrayComponent
                return binding._ref.el
        binding
    ArrayComponent
