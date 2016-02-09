deps = [
    '../common'
    '!componentHandler'
]

freact = ({_, $}, componentHandler)->
    class MdlComponent extends React.Component

        componentDidMount:->
            el = ReactDOM.findDOMNode @
            componentHandler.upgradeElement el

            return

        componentWillUnmount: ->
            @props.binding?.instance = @
            el = ReactDOM.findDOMNode @
            componentHandler.downgradeElements [el]
            return

        render:->
            React.createElement @props.tagName or 'span', @props, @props.children
