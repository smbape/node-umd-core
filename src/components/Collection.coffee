deps = [
    '../views/ReactCollectionView'
]

freact = (ReactCollectionView)->
    class Collecion extends ReactCollectionView
        constructor: (props)->
            super
            @childNode = @props.forEach

        render:->
            React.createElement @props.tagName or 'div', @props, @childNodeList()
