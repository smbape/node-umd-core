deps = [
    '../common'
    'umd-core/src/GenericUtil'
    './AbstractModelComponent'
]

freact = ({_, $}, {throttle}, AbstractModelComponent)->

    $document = $(document)

    closeRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.closeRightPanelHandled
        data.closeRightPanelHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-right'
        return

    closeLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.closeLeftPanelHandled
        data.closeLeftPanelHandled = true

        $(evt.currentTarget).closest('.layout').removeClass 'layout-open-left'
        return

    openRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.openHandled
        data.openHandled = true

        $(evt.currentTarget).closest('.layout').addClass 'layout-open-right'
        return

    openLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.openHandled
        data.openHandled = true

        $(evt.currentTarget).closest('.layout').addClass 'layout-open-left'
        return

    toggleRightPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.toggleHandled
        data.toggleHandled = true

        $(evt.currentTarget).closest('.layout').toggleClass 'layout-open-right'
        return

    toggleLeftPanel = (evt)->
        data = evt.originalEvent or evt
        return if data.toggleHandled
        data.toggleHandled = true

        $(evt.currentTarget).closest('.layout').toggleClass 'layout-open-left'
        return

    # from jquery touch swipe
    SUPPORTS_TOUCH = 'ontouchstart' of window
    SUPPORTS_POINTER_IE10 = window.navigator.msPointerEnabled and !window.navigator.pointerEnabled and !SUPPORTS_TOUCH
    SUPPORTS_POINTER = (window.navigator.pointerEnabled or window.navigator.msPointerEnabled) and !SUPPORTS_TOUCH

    if SUPPORTS_TOUCH or SUPPORTS_POINTER_IE10 or SUPPORTS_POINTER
        $document.swipe
            swipeRight: (evt, distance, duration, fingerCount, fingerData, currentDirection)->
                $(evt.target).trigger 'swipeRight'
                return
            swipeLeft: (evt, distance, duration, fingerCount, fingerData, currentDirection)->
                $(evt.target).trigger 'swipeLeft'
                return
            fingers: $.fn.swipe.fingers.ALL
            preventDefaultEvents: false

        $document.on 'swipeRight', '.layout > .layout__overlay, .layout > .layout__right', closeRightPanel
        $document.on 'swipeLeft', '.layout > .layout__overlay, .layout > .layout__left', closeLeftPanel

    $document.on 'click', '.layout > .layout__overlay', closeRightPanel

    $document.on 'click', '.layout > .layout__overlay', closeLeftPanel

    $document.on 'click', '.layout .layout-action-close-right', closeRightPanel
    $document.on 'click', '.layout .layout-action-close-left', closeLeftPanel

    $document.on 'click', '.layout .layout-action-open-right', openRightPanel
    $document.on 'click', '.layout .layout-action-open-left', openLeftPanel

    $document.on 'click', '.layout .layout-action-toggle-right', toggleRightPanel
    $document.on 'click', '.layout .layout-action-toggle-left', toggleLeftPanel

    class Layout extends AbstractModelComponent
        uid: 'Layout' + ('' + Math.random()).replace(/\D/g, '')

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
            if @el
                {el, $el} = this
            else
                el = ReactDOM.findDOMNode @
                $el = $ el

            parents = $el.parents('.layout').length

            if parents is 0
                @_doUpdateWitdh el, $el
            else
                # Wait until parents css animation is done
                # TODO: find a way to avoid transition on resize
                setTimeout =>
                    @_doUpdateWitdh el, $el
                    return
                , parents * 250
            return

        _doUpdateWitdh: (el, $el)->
            width = $el.width()
            if width < 1024
                el.setAttribute 'data-width', 'small'
            else if width < 1200
                el.setAttribute 'data-width', 'large'
            else
                el.setAttribute 'data-width', 'extra-large'

            return

        getProps: ->
            props = _.clone @props
            children = @props.children

            if props.className
                _className = [props.className, 'layout']
            else
                _className = ['layout']

            _children = []
            _remaining = []

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
                        _remaining.push child


                if not item.content
                    throw new Error "no content found"

                _children.push item.content
                _children.push `<div className="layout__overlay layout__overlay-center" />`

                if item.left
                    _className.push 'layout-has-left'
                    _children.push item.left
                    _children.push `<div className="layout__overlay layout__overlay-left" />`
                else
                    _children.push undefined
                    _children.push undefined

                if item.right
                    _className.push 'layout-has-right'
                    _children.push item.right
                else
                    _children.push undefined

            props.className = _className.join(' ')
            props.children = _children.concat _remaining
            props

        render: ->
            React.createElement 'div', @getProps()