import inherits from "../functions/inherits";
import i18n from "%{amd: 'i18next', common: 'i18next', brunch: '!i18next'}";
import React from "%{ amd: 'react', common: '!React' }";
import AbstractModelComponent from "./AbstractModelComponent";
import Dialog from "./Dialog";

const btnRaisedRipple = "mdl-button mdl-js-button mdl-button--raised mdl-js-ripple-effect";
const btnAccent = `${ btnRaisedRipple } mdl-button--accent`;
const btnCancel = `${ btnRaisedRipple } mdl-button--colored`;

function ConfirmDialog() {
    this.confirm = this.confirm.bind(this);
    this.close = this.close.bind(this);
    ConfirmDialog.__super__.constructor.apply(this, arguments);
}

inherits(ConfirmDialog, AbstractModelComponent);

Object.assign(ConfirmDialog.prototype, {

    showModal(content, opts) {
        const {close, confirm, from: _from} = opts;

        if (!content) {
            content = i18n.t("confirm.content");
        }

        let {title} = opts;
        if (!title) {
            title = i18n.t("confirm.title");
        }

        this.inline.set({
            content,
            title,
            close,
            confirm
        });

        this.getRef("dialog").showModal({
            from: _from
        });
    },

    close() {
        this.getRef("dialog").close();
        this.inline.clear();

        const close = this.inline.get("close");
        if ("function" === typeof (close)) {
            close();
        }
    },

    confirm() {
        const confirm = this.inline.get("confirm");
        if ("function" === typeof (confirm)) {
            confirm();
        }
        this.getRef("dialog").close();
        this.inline.clear();
    },

    render() {
        let {title, content} = this.inline.attributes;

        const ref1 = typeof title;
        if ((ref1) === "string" || ref1 === "number" || ref1 === "boolean") {
            title = <h4 className="" dangerouslySetInnerHTML={ { __html: title } } />;
        }

        const ref2 = typeof content;
        if ((ref2) === "string" || ref2 === "number" || ref2 === "boolean") {
            content = <span dangerouslySetInnerHTML={ { __html: content } } />;
        }

        return (<Dialog ref={ this.setRef("dialog") } spModel={ [this.inline, null, "change"] } className="mdl-dialog">
            { title }
            <div className="mdl-dialog__content" spModel="content">
                { content }
            </div>
            <div className="mdl-dialog__actions">
                <button type="button" className={ btnCancel } onClick={ this.close }>
                    { i18n.t("button.no") }
                </button>
                <button type="button" className={ btnAccent } onClick={ this.confirm }>
                    { i18n.t("button.yes") }
                </button>
            </div>
        </Dialog>);
    }

});

module.exports = ConfirmDialog;
