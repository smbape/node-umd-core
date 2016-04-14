deps = [
    '../common'
    '../GenericUtil'
    './AbstractModelComponent'
]

freact = ({_}, {mergeFunctions}, AbstractModelComponent)->

    class AutogrowTextarea extends AbstractModelComponent
        getInput: ->
            @getRef('input')

        _updateHeight: =>
            @refs.textareaSize.innerHTML = @getRef('input').value
            return

        componentDidMount: ->
            super
            @_updateHeight()
            return

        componentDidUpdate: ->
            super
            @_updateHeight()
            return

        render: ->
            props = _.defaults {
                ref: mergeFunctions @setRef('input'), @props.ref
                onInput: mergeFunctions @_updateHeight, @props.onInput
            }, @props

            textarea = React.createElement 'textarea', props
            `<div className="textarea-container">
                {textarea}
                <div ref="textareaSize" className="textarea-size" />
            </div>`
