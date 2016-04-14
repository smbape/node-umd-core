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
            @refs.textareaSize.innerHTML = @getRef('input').value + '\n'
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
            if @props.spModel
                onInput = @props.onInput
            else
                onInput = mergeFunctions @_updateHeight, @props.onInput

            props = _.defaults {
                ref: mergeFunctions @setRef('input'), @props.ref
                onInput
            }, @props

            textarea = React.createElement 'textarea', props
            `<div className="textarea-container">
                {textarea}
                <div ref="textareaSize" className="textarea-size" />
            </div>`
