
factory = ->
    eachSeries = (context, tasks, done)->
        index = 0
        length = tasks.length
        results = []

        iterate = (err, res)->
            results.push res

            if err || index is length
                done err, results
                return

            task = tasks[index++]

            if Array.isArray task
                task = task.slice()
                fn = task.shift()
                args = task
            else
                fn = task
                args = []

            if 'string' is typeof fn
                fn = context[fn]

            if 'function' isnt typeof fn
                iterate()
                return

            if fn.length > args.length
                args.push iterate
                fn.apply context, args
            else
                iterate null, fn.apply context, args

            return

        iterate()

        return
