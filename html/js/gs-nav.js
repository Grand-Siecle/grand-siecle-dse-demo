/*
 * Grand Siecle site header (xslt/partials/html_navbar.xsl): burger menu under 900px and
 * closing of the "Entités" dropdown (<details>) on outside click or Escape.
 * Replaces the Bootstrap collapse used by the MaX edition, so that the editorial pages
 * need neither jQuery nor the Bootstrap bundle. Without JavaScript the menu stays open
 * (html.gs-js is set by an inline script in <head>).
 */
(function () {
    'use strict';

    function init() {
        var toggler = document.querySelector('.gs-nav-toggler');
        var panel = document.getElementById('gsNavContent');
        if (toggler && panel) {
            toggler.addEventListener('click', function () {
                var open = panel.classList.toggle('show');
                toggler.setAttribute('aria-expanded', open ? 'true' : 'false');
            });
        }

        var dropdowns = document.querySelectorAll('.gs-nav-dropdown');
        document.addEventListener('click', function (ev) {
            dropdowns.forEach(function (d) {
                if (d.open && !d.contains(ev.target)) { d.open = false; }
            });
        });
        document.addEventListener('keydown', function (ev) {
            if (ev.key !== 'Escape') { return; }
            dropdowns.forEach(function (d) {
                if (d.open) {
                    d.open = false;
                    d.querySelector('summary').focus();
                }
            });
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
