import inherits from "../functions/inherits";
import throttle from "../functions/throttle";
import supportOnPassive from "../functions/supportOnPassive";
import $ from "%{amd: 'jquery', common: 'jquery', brunch: '!jQuery'}";
import React from "%{ amd: 'react', common: '!React' }";
import ReactDOM from "%{ amd: 'react-dom', common: '!ReactDOM' }";
import AbstractModelComponent from "./AbstractModelComponent";

const ceil = Math.ceil;
const $document = $(document);

const closeRightPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.closeRightPanelHandled) {
        return;
    }

    data.closeRightPanelHandled = true;
    $(evt.currentTarget).closest(".layout").removeClass("layout-open-right");
};


const closeLeftPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.closeLeftPanelHandled) {
        return;
    }

    data.closeLeftPanelHandled = true;
    $(evt.currentTarget).closest(".layout").removeClass("layout-open-left");
};

const openRightPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.openHandled) {
        return;
    }

    data.openHandled = true;
    $(evt.currentTarget).closest(".layout").addClass("layout-open-right");
};

const openLeftPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.openHandled) {
        return;
    }

    data.openHandled = true;
    $(evt.currentTarget).closest(".layout").addClass("layout-open-left");
};

const toggleRightPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.toggleHandled) {
        return;
    }

    data.toggleHandled = true;
    $(evt.currentTarget).closest(".layout").toggleClass("layout-open-right");
};

const toggleLeftPanel = function(evt) {
    const data = evt.originalEvent || evt;
    if (data.toggleHandled) {
        return;
    }

    data.toggleHandled = true;
    $(evt.currentTarget).closest(".layout").toggleClass("layout-open-left");
};

const START_EV = "touchstart mousedown";
const MOVE_EV = "touchmove mousemove";
let END_EV = "touchend mouseup";
const CANCEL_EV = "touchcancel mouseleave";
END_EV = [END_EV, CANCEL_EV].join(" ");
const START_EV_MAP = {
    touchstart: /^touch/,
    mousedown: /^mouse/
};

$document.on("click", ".layout > .layout__overlay", closeRightPanel);
$document.on("click", ".layout > .layout__overlay", closeLeftPanel);
$document.on("click", ".layout .layout-action-close-right", closeRightPanel);
$document.on("click", ".layout .layout-action-close-left", closeLeftPanel);
$document.on("click", ".layout .layout-action-open-right", openRightPanel);
$document.on("click", ".layout .layout-action-open-left", openLeftPanel);
$document.on("click", ".layout .layout-action-toggle-right", toggleRightPanel);
$document.on("click", ".layout .layout-action-toggle-left", toggleLeftPanel);

const testElementStyle = document.createElement("div").style;
const transformJSPropertyName = "transform" in testElementStyle ? "transform" : "webkitTransform";
// const userSelectJSPropertyName = "userSelect" in testElementStyle ? "userSelect" : "webkitUserSelect";

const MAX_TAN = Math.tan(45 * Math.PI / 180);
const MAX_TEAR = 5;

function Layout() {
    this._updateWidth = this._updateWidth.bind(this);
    this.onTouchEnd = this.onTouchEnd.bind(this);
    this.onTouchMove = this.onTouchMove.bind(this);
    this.onTouchStart = this.onTouchStart.bind(this);
    Layout.__super__.constructor.apply(this, arguments);
}

inherits(Layout, AbstractModelComponent);

Object.assign(Layout.prototype, {
    uid: `Layout${ (String(Math.random())).replace(/\D/g, "") }`,

    componentDidMount() {
        this._updateWidth();
        const count = $(ReactDOM.findDOMNode(this)).parents(".layout").length + 1;
        this._updateWidth = throttle(this._updateWidth, count * 4, {
            leading: false
        });
        Layout.__super__.componentDidMount.apply(this, arguments);
    },

    attachEvents() {
        window.addEventListener("resize", this._updateWidth, true);
        if (this.$el) {
            const restore = supportOnPassive($, START_EV);
            this.$el.on(START_EV, "> .layout__left, > .layout__right", this.onTouchStart);
            restore();
        }
    },

    detachEvents() {
        if (this.$el) {
            this.$el.off(START_EV, "> .layout__left, > .layout__right", this.onTouchStart);
        }

        if (this._moveState) {
            this._moveState.removeTouchEventListeners();
        }

        if (this._updateWidth.cancel) {
            this._updateWidth.cancel();
        }

        window.removeEventListener("resize", this._updateWidth, true);
    },

    _getCurrentTarget(evt) {
        const data = evt.originalEvent || evt;

        if (data.targetPanelHandled) {
            return null;
        }

        data.targetPanelHandled = true;
        return $(evt.currentTarget);
    },

    getPosition(evt) {
        const touches = evt.touches;

        if (touches) {
            return {
                x: touches[0].clientX,
                y: touches[0].clientY
            };
        }

        return {
            x: evt.clientX,
            y: evt.clientY
        };
    },

    onTouchStart(evt) {
        if (this._moveState) {
            // touchevents are more reliable than pointer events on Chrome 55-56
            if (evt.type === "touchstart" && this._moveState.type !== evt.type) {
                this._moveState.type = evt.type;
                this._moveState.regex = START_EV_MAP[evt.type];
            }
            return;
        }

        // only care about single touch
        if (evt.touches && evt.touches.length !== 1) {
            return;
        }

        let $target = this._getCurrentTarget(evt);
        if (!$target || !$target.length) {
            return;
        }

        this._moveState = Object.assign(this.getPosition(evt), {
            type: evt.type,
            regex: START_EV_MAP[evt.type],
            target: $target[0],
            isLeft: $target.hasClass("layout__left"),
            timerInit: Date.now()
        });

        this._inMove = false;
        this._inVScroll = false;

        let scrollContainer = evt.target;
        while (scrollContainer && scrollContainer !== document.body) {
            if (scrollContainer.scrollHeight > scrollContainer.clientHeight) {
                break;
            }
            scrollContainer = scrollContainer.parentNode;
        }

        if (scrollContainer !== document.body) {
            this._moveState.scrollContainer = scrollContainer;
        }

        const restore = supportOnPassive($, `${ MOVE_EV } ${ END_EV }`);
        $target.on(MOVE_EV, this.onTouchMove);
        $target.on(END_EV, this.onTouchEnd);
        restore();

        this._moveState.removeTouchEventListeners = () => {
            $target.off(MOVE_EV, this.onTouchMove);
            $target.off(END_EV, this.onTouchEnd);
            $target = null;
        };
    },

    onTouchMove(evt) {
        if (!this._moveState || !this._moveState.regex.test(evt.type)) {
            return;
        }

        if (!this._inVScroll && this.el.getAttribute("data-width") === "small") {
            const {x: startX, y: startY, isLeft, target, scrollContainer} = this._moveState;
            const {x, y} = this.getPosition(evt);

            let diffX = x - startX;
            const diffY = y - startY;
            const aDiffX = diffX < 0 ? -diffX : diffX;
            const aDiffY = diffY < 0 ? -diffY : diffY;

            if (!this._inMove && (aDiffX === 0 || MAX_TAN < (aDiffY / aDiffX))) {
                this._inVScroll = true;
                this.onTouchEnd(evt, true);
                return;
            }

            if (!this._inMove) {
                this._moveState.target.style.transition = "none";
                this._inMove = true;
            }

            let tx;

            if (isLeft) {
                this._moveState.diffX = -diffX;
                if (diffX > MAX_TEAR) {
                    diffX = MAX_TEAR;
                }
                tx = `translateX(${ ceil(diffX) }px)`;
            } else {
                this._moveState.diffX = diffX;
                if (-diffX > MAX_TEAR) {
                    diffX = -MAX_TEAR;
                }
                tx = `translateX(-100%) translateX(${ ceil(diffX) }px)`;
            }

            if (scrollContainer) {
                scrollContainer.style.overflow = "hidden";
            }

            target.style[transformJSPropertyName] = tx;
        }
    },

    onTouchEnd(evt, fromMove) {
        if (!this._moveState || (!fromMove && !this._moveState.regex.test(evt.type))) {
            return;
        }

        const {target, scrollContainer, diffX, timerInit, removeTouchEventListeners} = this._moveState;
        removeTouchEventListeners();

        if (this._inMove) {
            target.style.transition = "";
            target.style[transformJSPropertyName] = "";

            const timerDiff = Date.now() - timerInit;
            if ((timerDiff < 200 && diffX > 0) || diffX > $(target).width() / 3) {
                this.$el.removeClass("layout-open-left layout-open-right");
            }
        }

        if (scrollContainer) {
            scrollContainer.style.overflow = "";
        }

        this._moveState.target = null;
        this._moveState.scrollContainer = null;
        this._moveState = null;
    },

    _updateWidth() {
        let el, $el;

        if (this.el) {
            el = this.el;
            $el = this.$el;
        } else {
            el = ReactDOM.findDOMNode(this);
            $el = $(el);
        }

        const width = $el.width();
        if (width < 768) {
            el.setAttribute("data-width", "small");
        } else if (width < 1200) {
            el.setAttribute("data-width", "large");
        } else {
            el.setAttribute("data-width", "extra-large");
        }
    },

    getProps() {
        const props = Object.assign({}, this.props);
        let {children} = props;

        let _className, match, name;

        if (props.className) {
            _className = [props.className, "layout"];
        } else {
            _className = ["layout"];
        }

        const _remaining = [];
        const _children = [];

        props.children = _children;

        if (children) {
            if (!Array.isArray(children)) {
                children = [children];
            }

            const item = {};

            children.forEach(child => {
                if (!child) {
                    return;
                }

                const className = child.props && child.props.className;

                if (className) {
                    const re = /(?:^|\s)layout__(content|left|right)(?:\s|$)/g;
                    match = re.exec(className);

                    if (match) {
                        while (match) {
                            [match, name] = match;

                            switch (name) {
                                case "content":
                                    item.content = child;
                                    break;
                                case "left":
                                    item.left = child;
                                    break;
                                case "right":
                                    item.right = child;
                                    break;
                                default:
                                    // Nothing to do
                            }

                            match = re.exec(className);
                        }
                    } else {
                        _remaining.push(child);
                    }
                } else {
                    _remaining.push(child);
                }
            });

            if (!item.content) {
                throw new Error("no content found");
            }

            _children.push(item.content);
            _children.push(<div className="layout__overlay layout__overlay-center" />);

            if (item.left) {
                _className.push("layout-has-left");
                _children.push(item.left);
                _children.push(<div className="layout__overlay layout__overlay-left" />);
            } else {
                _children.push(undefined);
                _children.push(undefined);
            }

            if (item.right) {
                _className.push("layout-has-right");
                _children.push(item.right);
            } else {
                _children.push(undefined);
            }
        }

        _children.push(..._remaining);
        props.className = _className.join(" ");
        return props;
    },

    render() {
        return React.createElement("div", this.getProps());
    }

});

module.exports = Layout;
