
deps = [
    './common'
    './GenericUtil'
]

factory = ({_, Backbone}, Util)->
    class ClientController extends Backbone.Model

        getMethod: ({pathParams})->
            if 'string' is typeof pathParams?.action
                Util.StringUtil.toCamelDash(pathParams.action.toLowerCase()) + 'Action'

        getUrl: (params, options)->
            if not options?.reset
                params = _.extend {}, @get('pathParams'), params

            @get('engine').getUrl(params, options)

        render: (View, options, done)->
            switch arguments.length
                when 0
                    return
                when 1
                    done = View
                    view = @view
                when 2
                    done = options
                    options =
                        container: @get('container')
                        controller: @
                    view = @view = View.createElement options
                else
                    options = _.extend options,
                        container: @get('container')
                        controller: @
                    view = @view = View.createElement options

            if 'function' isnt typeof view.render or view.render.length > 1
                return done(new Error "invalid render method. It should be a function expectingat most ine argument")

            if view.render.length is 1
                timeout = setTimeout ->
                    console.log 'taking too long to render. Make sure you called done function'
                    return
                , 1000
                try
                    view.render (err)->
                        clearTimeout timeout
                        done err, view
                        return
                catch err
                    clearTimeout timeout
                    done err, view

            else
                try
                    view.render()
                catch err
                done err, view

            return

        navigate: (url, options)->
            if _.isObject(url)
                url = @getUrl url, options

            @get('router').navigate url, _.extend {trigger: true}, options
            return

        destroy: ->
            if @view
                @view.destroy()

            for own prop of @
                delete @[prop]

            return

    ClientController::emit = ClientController::trigger

    ClientController
