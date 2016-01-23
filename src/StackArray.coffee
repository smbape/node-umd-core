factory = ->
    class StackArray extends Array
        constructor: (@maxlength = 6)->
        push: (item)->
            length = @length + 1
            while @length > 0 and @length + 1 > @maxlength
                @shift()
            Array::push.call @, item
        get: (index)->
            index = @length + index if index < 0
            @[index]
        range: (start, end)->
            @slice start, end
        clear: ->
            @splice 0, @length
