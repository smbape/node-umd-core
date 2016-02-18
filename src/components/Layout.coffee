deps = [
    '../common'
    './AbstractModelComponent'
]

freact = ({_, $}, AbstractModelComponent)->

    $document = $(document)

    $document.swipe
        swipeRight: (evt, distance, duration, fingerCount, fingerData, currentDirection)->
            $(evt.target).trigger 'swipeRight'
            return
        swipeLeft: (evt, distance, duration, fingerCount, fingerData, currentDirection)->
            $(evt.target).trigger 'swipeLeft'
            return
        fingers: $.fn.swipe.fingers.ALL

    
    closeRightPanel = (evt)->
        if evt.type.substring(0, 5) is 'swipe'
            data = evt.originalEvent or evt
            return if data.swipeHandled
            data.swipeHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-right'
        return

    closeLeftPanel = (evt)->
        if evt.type.substring(0, 5) is 'swipe'
            data = evt.originalEvent or evt
            return if data.swipeHandled
            data.swipeHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-left'
        return

    $document.on 'click swipeRight', '.layout__overlay', closeRightPanel
    $document.on 'swipeRight', '.layout__right', closeRightPanel

    $document.on 'click swipeLeft', '.layout__overlay', closeLeftPanel
    $document.on 'swipeLeft', '.layout__left', closeLeftPanel

    class Layout extends AbstractModelComponent
        uid: 'Layout' + ('' + Math.random()).replace(/\D/g, '')

        constructor: ->
            super

        componentDidMount: ->
            @_updateWidth()
            super
            $(window).on 'resize', @_updateWidth
            return

        componentWillUnmount: ->
            $(window).off 'resize', @_updateWidth
            super()
            return

        _updateWidth: =>
            el = ReactDOM.findDOMNode @

            width = $(el).width()
            if width < 1024
                el.setAttribute 'data-width', 'small'
            else if width < 1200
                el.setAttribute 'data-width', 'large'
            else
                el.setAttribute 'data-width', 'extra-large'

            return

        getChildren: ->
            children = @props.children
            _children = []

            if children
                item = {}
                for child, idx in children
                    continue if not child

                    className = child.props.className

                    if /(?:^|\s)layout__content(?:\s|$)/.test className
                        item.content = child
                    else if /(?:^|\s)layout__left(?:\s|$)/.test className
                        item.left = child
                    else if /(?:^|\s)layout__right(?:\s|$)/.test className
                        item.right = child
                    else
                        throw new Error "invalid children at index #{idx}"


                if not item.content
                    throw new Error "no content found"

                _children.push item.content
                _children.push `<div className="layout__overlay layout__overlay-center" />`

                if item.left
                    _children.push item.left
                    _children.push `<div className="layout__overlay layout__overlay-left" />`

                if item.right
                    _children.push item.right
            
            return _children

        render: ->
            props = _.clone @props
            if props.className
                props.className += ' layout'
            else
                props.className = 'layout'
            props.children = @getChildren()
            React.createElement 'div', props