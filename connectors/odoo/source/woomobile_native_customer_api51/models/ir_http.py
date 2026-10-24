"""Only this addon's Native session response gets the stronger cookie flags."""

from odoo import http, models
from odoo.http import request


class IrHttp(models.AbstractModel):
    _inherit = 'ir.http'

    @classmethod
    def _post_dispatch(cls, response):
        # In Odoo 18 this calls Dispatcher.post_dispatch -> _save_session ->
        # _inject_future_response. Therefore the final, rotated sid is already
        # stored and its cookie already injected before the localized rewrite.
        super()._post_dispatch(response)
        path = request.httprequest.path
        if not (path == '/api/mobile/v1/customer' or path.startswith('/api/mobile/v1/customer/')):
            return
        if not request.db or not request.session:
            return
        # Remove only the previous same-name cookie. Preserve language, website,
        # consent and every other cookie emitted by normal Odoo dispatch.
        original = response.headers.getlist('Set-Cookie')
        response.headers.setlist('Set-Cookie', [
            cookie for cookie in original
            if cookie.split('=', 1)[0].strip() != 'session_id'
        ])
        response.set_cookie(
            'session_id', request.session.sid,
            max_age=http.get_session_max_inactivity(request.env),
            path='/', httponly=True, secure=True, samesite='Strict',
        )
