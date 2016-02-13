deps = ['../common']

freact = ({_, $})->

    class AbstractModelComponent extends React.Component
        uid: 'AbstractModelComponent' + ('' + Math.random()).replace(/\D/g, '')

        componentWillMount: ->
            {spModel: [model, attr]} = @props
            @attachEvents model, attr

            return

        componentWillUnmount: ->
            {spModel: [model, attr]} = @props
            @detachEvents model, attr

            # remove every references
            for own prop of @
                delete @[prop]

            return

        componentWillReceiveProps: (nextProps)->
            {spModel: [model, attr]} = nextProps
            {spModel: [oldModel, oldAttr]} = @props

            if model isnt oldModel or attr isnt oldAttr
                @detachEvents oldModel, oldAttr
                @attachEvents model, attr
                @shouldUpdate = true

            return

        attachEvents: (model, attr)->
            events = "change:#{attr}"
            model.on events, @_updateOwner, @
            return

        detachEvents: (model, attr)->
            events = "change:#{attr}"
            model.off events, @_updateOwner, @
            return

        shouldComponentUpdate: (nextProps, nextState)->
            shouldUpdate = @shouldUpdate or !_.isEqual(@state, nextState) or !_.isEqual(@props, nextProps)
            @shouldUpdate = false
            shouldUpdate

        _updateOwner: ->
            @shouldUpdate = true
            {spModel: [model, attr]} = @props
            if model.invalidAttrs[attr]
                @className = 'input--invalid'
                @isValid = false
            else
                @className = ''
                @isValid = true

            if @_reactInternalInstance
                owner = @_reactInternalInstance._currentElement._owner._instance
                state = {}
                state[@uid] = new Date().getTime()
                owner.setState state
            return
