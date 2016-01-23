deps = [
    '../common'
    '../models/BackboneCollection'
    './ReactModelView'
]

factory = ({_}, BackboneCollection, ReactModelView)->

    class ReactCollectionView extends ReactModelView
        constructor: (options = {})->
            super

            if @model and not (@model instanceof BackboneCollection)
                throw new Error 'model must be an instance of BackboneCollection'
