
factory = ->
    class FIFOSemaphore
        constructor: (@_capacity)->
            @_queue = []
            @_basket = @_capacity

        available: ->
            @_queue and @_basket isnt 0

        take: (callback)->
            if 'function' is typeof callback
                @_queue.push callback
                @_dequeue()
            return

        give: ->
            if @_basket < @_capacity
                ++@_basket
                @_dequeue()

            return

        _dequeue: ->
            return if not @_queue or 0 is @_queue.length or 0 is @_basket
            @_basket--
            callback = @_queue.shift()
            callback()
            @_dequeue()
            return

        destroy: ->
            for own prop of @
                delete @[prop]

            return
