deps = [
    '../common'
    './AbstractModelComponent'
    './Dialog'
]

freact = ({_, i18n}, AbstractModelComponent, Dialog)->
    btnRaisedRipple = 'mdl-button mdl-js-button mdl-button--raised mdl-js-ripple-effect'
    btnAccent = btnRaisedRipple + ' mdl-button--accent'
    btnDanger = btnRaisedRipple + ' btn-danger'
    btnCancel = btnRaisedRipple + ' mdl-button--colored'

    btnFabAccent = btnAccent + ' mdl-button--fab'
    btnFabDanger = btnDanger + ' mdl-button--fab'
    btnFabCancel = btnCancel + ' mdl-button--fab'

    btnMiniFabAccent = btnFabAccent + ' mdl-button--mini-fab'
    btnMiniFabDanger = btnFabDanger + ' mdl-button--mini-fab'
    btnMiniFabCancel = btnFabCancel + ' mdl-button--mini-fab'

    computeLength = (str)->
        str and str.length or 0

    class ConfirmDialog extends AbstractModelComponent
        showModal: (content, {title, close, confirm} = {})->
            if not content
                content = i18n.t('confirm.content')
            if not title
                title = i18n.t('confirm.title')
            @inline.set {content, title, close, confirm}
            @getRef('dialog').showModal()
            return

        close: =>
            @getRef('dialog').close()
            @inline.clear()
            if 'function' is typeof close = @inline.get('close')
                close()
            return

        confirm: =>
            if 'function' is typeof confirm = @inline.get('confirm')
                confirm()

            @getRef('dialog').close()
            @inline.clear()
            return

        render: ->
            {title, content} = @inline.attributes
            if typeof title in ['string', 'number', 'boolean']
                title = `<h4 className="" dangerouslySetInnerHTML={{__html: title}} />`

            if typeof content in ['string', 'number', 'boolean']
                content = `<span dangerouslySetInnerHTML={{__html: content}} />`

            `<Dialog ref={this.setRef('dialog')} spModel={[this.inline, null, 'change']} className="mdl-dialog">
                { title }
                <div className="mdl-dialog__content" spModel="content">
                    { content }
                </div>
                <div className="mdl-dialog__actions">
                    <button type="button" className={btnCancel} onClick={ this.close }>{ i18n.t('button.no') }</button>
                    <button type="button" className={btnAccent} onClick={ this.confirm }>{ i18n.t('button.yes') }</button>
                </div>
            </Dialog>`
