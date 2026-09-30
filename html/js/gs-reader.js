/*
 * Grand Siecle reading page (xslt/editions.xsl): layer switch (orig / reg), forme work
 * toggle, word analysis tooltip, page jump, keyboard navigation (left / right arrows),
 * facsimile fallback. Behaviour modelled on the MaX edition (ui/js/grand-siecle.js).
 * Everything works without this script except the toggles: the default layer is set
 * in the HTML (html/@data-layer).
 */
(function () {
    'use strict';

    var root = document.documentElement;
    var doc = root.getAttribute('data-doc') || 'global';

    function lsGet(key) {
        try { return window.localStorage.getItem('gs.' + key); } catch (e) { return null; }
    }
    function lsSet(key, value) {
        try { window.localStorage.setItem('gs.' + key, value); } catch (e) { /* private mode */ }
    }

    function setPressed(btn, on) {
        btn.setAttribute('aria-pressed', on ? 'true' : 'false');
        btn.classList.toggle('is-active', on);
    }

    /* ---------------------------------------------------------------- layers */
    var LAYER_KEY = 'layer.' + doc;
    var status = document.querySelector('.gs-ling-status');

    function applyLayer(layer) {
        root.setAttribute('data-layer', layer);
        document.querySelectorAll('.gs-layer-btn').forEach(function (btn) {
            setPressed(btn, btn.getAttribute('data-value') === layer);
        });
    }

    /* ------------------------------------------------------- word analysis */
    var lingBtn = document.querySelector('.gs-ling-btn');

    function setLing(on) {
        document.body.classList.toggle('gs-ling-on', on);
        if (lingBtn) { setPressed(lingBtn, on); }
        lsSet('ling', on ? 'on' : 'off');
        if (status) { status.textContent = ''; }
        if (!on) { hideTooltip(); }
        /* word annotations only exist in the original layer */
        if (on && root.getAttribute('data-layer') === 'reg') {
            applyLayer('orig');
            lsSet(LAYER_KEY, 'orig');
            if (status) { status.textContent = 'affichée sur la couche originale'; }
        }
    }

    var tooltip = null;
    function hideTooltip() { if (tooltip) { tooltip.hidden = true; } }

    function showTooltip(w) {
        var lemma = w.getAttribute('data-lemma') || '';
        var pos = w.getAttribute('data-pos') || '';
        var msd = (w.getAttribute('data-msd') || '').split('|').join(' · ');
        if (!lemma && !pos) { return; }
        if (!tooltip) {
            tooltip = document.createElement('div');
            tooltip.className = 'gs-tooltip';
            tooltip.setAttribute('role', 'tooltip');
            document.body.appendChild(tooltip);
        }
        tooltip.textContent = '';
        var l1 = document.createElement('div');
        l1.className = 'gs-tt-line1';
        l1.textContent = lemma || w.textContent;
        if (pos) {
            var p = document.createElement('span');
            p.className = 'gs-tt-pos';
            p.textContent = ' (' + pos + ')';
            l1.appendChild(p);
        }
        tooltip.appendChild(l1);
        if (msd) {
            var l2 = document.createElement('div');
            l2.className = 'gs-tt-msd';
            l2.textContent = msd;
            tooltip.appendChild(l2);
        }
        var r = w.getBoundingClientRect();
        tooltip.hidden = false;
        var left = Math.min(r.left + window.scrollX,
            window.scrollX + document.documentElement.clientWidth - tooltip.offsetWidth - 8);
        tooltip.style.left = Math.max(4, left) + 'px';
        tooltip.style.top = (r.bottom + window.scrollY + 6) + 'px';
    }

    /* ------------------------------------------------------------- init */
    document.addEventListener('DOMContentLoaded', function () {
        var stored = lsGet(LAYER_KEY);
        applyLayer(stored === 'orig' || stored === 'reg' ? stored : (root.getAttribute('data-default-layer') || 'reg'));
        document.querySelectorAll('.gs-layer-btn').forEach(function (btn) {
            btn.addEventListener('click', function () {
                var layer = btn.getAttribute('data-value');
                applyLayer(layer);
                lsSet(LAYER_KEY, layer);
                if (layer === 'reg' && document.body.classList.contains('gs-ling-on')) { setLing(false); }
            });
        });

        var fwBtn = document.querySelector('.gs-fw-btn');
        if (fwBtn) {
            var fwOn = lsGet('fw') === 'on';
            document.body.classList.toggle('gs-show-fw', fwOn);
            setPressed(fwBtn, fwOn);
            fwBtn.addEventListener('click', function () {
                var on = document.body.classList.toggle('gs-show-fw');
                setPressed(fwBtn, on);
                lsSet('fw', on ? 'on' : 'off');
            });
        }

        if (lingBtn) {
            if (lsGet('ling') === 'on') { setLing(true); } else { setPressed(lingBtn, false); }
            lingBtn.addEventListener('click', function () {
                setLing(!document.body.classList.contains('gs-ling-on'));
            });
        }
        document.addEventListener('mouseover', function (ev) {
            if (!document.body.classList.contains('gs-ling-on')) { return; }
            var w = ev.target.closest && ev.target.closest('.w');
            if (w) { showTooltip(w); } else { hideTooltip(); }
        });
        document.addEventListener('keydown', function (ev) {
            if (ev.key === 'Escape') { hideTooltip(); }
        });

        /* page jump */
        var form = document.querySelector('form.gs-jump');
        if (form) {
            form.addEventListener('submit', function (ev) {
                ev.preventDefault();
                var input = form.querySelector('input');
                var max = parseInt(form.getAttribute('data-max'), 10);
                var n = parseInt(input.value, 10);
                if (isNaN(n) || n < 1 || n > max) {
                    input.setCustomValidity('Page entre 1 et ' + max);
                    input.reportValidity();
                    return;
                }
                window.location.href = form.getAttribute('data-doc') + '-page-' + n + '.html';
            });
            form.querySelector('input').addEventListener('input', function () { this.setCustomValidity(''); });
        }

        /* facsimile fallback when Gallica does not answer */
        document.querySelectorAll('.page-facsimile img').forEach(function (img) {
            img.addEventListener('error', function () {
                var fig = img.closest('figure');
                var link = img.closest('a');
                var msg = document.createElement('p');
                msg.className = 'gs-facs-fallback';
                msg.textContent = 'Fac-similé indisponible. ';
                if (link) {
                    var a = document.createElement('a');
                    a.href = link.href;
                    a.textContent = 'Voir la page sur Gallica';
                    msg.appendChild(a);
                }
                (link || img).replaceWith(msg);
                if (fig) { fig.classList.add('is-failed'); }
            });
        });
    });

    /* keyboard navigation: left / right arrows go to the previous / next page */
    document.addEventListener('keydown', function (ev) {
        if (ev.key !== 'ArrowLeft' && ev.key !== 'ArrowRight') { return; }
        if (ev.ctrlKey || ev.metaKey || ev.altKey || ev.shiftKey) { return; }
        var t = ev.target;
        if (t && (/^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(t.tagName) || t.isContentEditable)) { return; }
        var link = document.querySelector(ev.key === 'ArrowLeft' ? 'a.gs-page-prev' : 'a.gs-page-next');
        if (link) { window.location.href = link.href; }
    });
}());
