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

    useTouchEvents = SUPPORTS_TOUCH
    START_EV = if useTouchEvents then (if SUPPORTS_POINTER then (if SUPPORTS_POINTER_IE10 then 'MSPointerDown' else 'pointerdown') else 'touchstart') else 'mousedown'
    MOVE_EV = if useTouchEvents then (if SUPPORTS_POINTER then (if SUPPORTS_POINTER_IE10 then 'MSPointerMove' else 'pointermove') else 'touchmove') else 'mousemove'
    END_EV = if useTouchEvents then (if SUPPORTS_POINTER then (if SUPPORTS_POINTER_IE10 then 'MSPointerUp' else 'pointerup') else 'touchend') else 'mouseup'
    CANCEL_EV = if SUPPORTS_POINTER then (if SUPPORTS_POINTER_IE10 then 'MSPointerCancel' else 'pointercancel') else 'touchcancel'

    $document.on 'click', '.layout > .layout__overlay', closeRightPanel
    $document.on 'click', '.layout > .layout__overlay', closeLeftPanel

    $document.on 'click', '.layout .layout-action-close-right', closeRightPanel
    $document.on 'click', '.layout .layout-action-close-left', closeLeftPanel

    $document.on 'click', '.layout .layout-action-open-right', openRightPanel
    $document.on 'click', '.layout .layout-action-open-left', openLeftPanel

    $document.on 'click', '.layout .layout-action-toggle-right', toggleRightPanel
    $document.on 'click', '.layout .layout-action-toggle-left', toggleLeftPanel

    testElementStyle = document.createElement('div').style
    transformJSPropertyName = if 'transform' of testElementStyle then 'transform' else 'webkitTransform'
    userSelectJSPropertyName = if 'userSelect' of testElementStyle then 'userSelect' else 'webkitUserSelect'
    testElementStyle = null

    END_EV = [END_EV, CANCEL_EV, userSelectJSPropertyName].join(' ')
    MAX_TAN = Math.tan(35 * Math.PI / 180)
    MAX_TEAR = 5

    class Layout extends AbstractModelComponent
        uid: 'Layout' + ('' + Math.random()).replace(/\D/g, '')

        componentDidMount: ->
            @_updateWidth()
            super
            $(window).on 'resize', @_updateWidth

            @getPosition = if useTouchEvents then @_getTouchPosition else @_getMousePosition

            @$el.on START_EV, @onTouchStart
            @$el.on MOVE_EV, @onTouchMove
            @$el.on END_EV, @onTouchEnd
            return

        _getCurrentTarget: (evt)->
            data = evt.originalEvent or evt
            return if data.targetPanelHandled
            data.targetPanelHandled = true
            $(evt.target).closest('.layout > .layout__left, .layout > .layout__right')

        _getTouchPosition: (evt)->
            x: evt.touches[0].clientX
            y: evt.touches[0].clientY

        _getMousePosition: (evt)->
            x: evt.clientX
            y: evt.clientY

        onTouchStart: (evt)=>
            # only care about single touch
            if useTouchEvents
                if evt.touches.length > 1
                    return

            $target = @_getCurrentTarget(evt)
            return if not $target or not $target.length

            @_panelState = @getPosition(evt)
            @_panelState.target = $target[0]
            @_panelState.isLeft = $target.hasClass('layout__left')
            @_panelState.timerInit = new Date().getTime()

            @_inMove = false
            @_inVScroll = false

            scrollContainer = evt.target
            while scrollContainer and scrollContainer isnt document.body
                break if scrollContainer.scrollHeight > scrollContainer.clientHeight
                scrollContainer = scrollContainer.parentNode

            if scrollContainer isnt document.body
                @_panelState.scrollContainer = scrollContainer
            return

        onTouchMove: (evt)=>
            if not @_inVScroll and @_panelState and @el.getAttribute('data-width') is 'small'
                {x: startX, y: startY, isLeft, target, scrollContainer, timerInit} = @_panelState
                {x, y} = @getPosition(evt)
                diffX = x - startX
                diffY = y - startY
                aDiffX = if diffX < 0 then -diffX else diffX
                aDiffY = if diffY < 0 then -diffY else diffY

                if not @_inMove and (aDiffX is 0 or MAX_TAN < (aDiffY / aDiffX))
                    @_inVScroll = true
                    @onTouchEnd evt
                    return

                @_inMove = true
                if isLeft
                    @_panelState.diffX = -diffX
                    if diffX > MAX_TEAR
                        diffX = MAX_TEAR
                    tx = "#{diffX}px"
                else
                    @_panelState.diffX = diffX
                    if -diffX > MAX_TEAR
                        diffX = -MAX_TEAR
                    tx = "calc(-100% + #{diffX}px)"

                timerDiff = new Date().getTime() - timerInit
                if timerDiff >= 200
                    scrollContainer.style.overflow = 'hidden' if scrollContainer
                    target.style.transition = 'none'
                    target.style[transformJSPropertyName] = "translateX(#{tx})"
            return

        onTouchEnd: (evt)=>
            if @_panelState
                {x: startX, y: startY, isLeft, target, scrollContainer, diffX, timerInit} = @_panelState
                if @_inMove
                    timerDiff = new Date().getTime() - timerInit
                    if timerDiff < 200 or diffX > $(target).width() / 3
                        @$el.removeClass if isLeft then 'layout-open-left' else 'layout-open-right'
                scrollContainer.style.overflow = '' if scrollContainer
                target.style.transition = ''
                target.style[transformJSPropertyName] = ''
                @_panelState.target = null
                @_panelState.scrollContainer = null
                @_panelState = null
            return

        componentWillUnmount: ->
            @$el.off START_EV, @onTouchStart
            @$el.off MOVE_EV, @onTouchMove
            @$el.off END_EV, @onTouchEnd
            $(window).off 'resize', @_updateWidth
            super()
            return

        _updateWidth: =>
            if @el
                {el, $el} = this
            else
                el = ReactDOM.findDOMNode @
                $el = $ el

            parents = $el.parents('[class^=layout__],[class*= layout__]')

            if parents.length is 0
                @_doUpdateWitdh el, $el
            else
                # Wait until parents css animation is done
                # TODO: find a way to avoid transition on resize
                onTransitioned = (evt)=>
                    clearTimeout timeout
                    parents.off 'transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd', onTransitioned
                    @_doUpdateWitdh el, $el
                    return
                timeout = setTimeout onTransitioned, parents.length * 250
                parents.one 'transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd', onTransitioned
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

            props.children = _children = []
            _remaining = []

            if children
                item = {}
                for child, idx in children
                    continue if not child

                    if className = child.props.className
                        re = /(?:^|\s)layout__(content|left|right)(?:\s|$)/g
                        if match = re.exec(className)
                            while match
                                [match, name] = match
                                switch name
                                    when 'content'
                                        item.content = child
                                    when 'left'
                                        item.left = child
                                    when 'right'
                                        item.right = child

                                match = re.exec(className)
                        else
                            _remaining.push child
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

            _children.push.apply _children, _remaining
            props.className = _className.join(' ')
            props

        render: ->
            React.createElement 'div', @getProps()