deps = [
    '../views/ReactCollectionView'
]

freact = (ReactCollectionView)->
    class Collecion extends ReactCollectionView
        tagName: 'div'
        constructor: (props)->
            super
            @childNode = @props.forEach

        render:->
            React.createElement @tagName, @props, @childNodeList()
