factory = ->
    # compare(a, b) return true if a > b
    binaryIndexComparator = (item, array, compare)->
        low = 0
        high = array.length
        while high > low
            mid = (low + high) >>> 1
            if compare(array[mid], item)
                high = mid
            else
                low = mid + 1
        low

    binaryIndex = (item, array)->
        low = 0
        high = array.length
        while high > low
            mid = (low + high) >>> 1
            if array[mid] > item
                high = mid
            else
                low = mid + 1
        low

    class SortedArray extends Array
        constructor: (comparator)->
            if 'function' is typeof comparator
                @comparator = comparator
                @_find = binaryIndexComparator
            else
                @_find = binaryIndex
            super()

        add: ->
            for item in arguments
                index = @_find item, @, @comparator
                @splice index, 0, item
            @length
        sort: (comparator)->
            super comparator or @comparator

    SortedArray::unshift = SortedArray::push = SortedArray::add
    SortedArray
