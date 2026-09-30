/**
 * gs-chronologie.js — Grand Siècle, démonstration DSE (J4)
 * Timeline without dependency, port of ui/js/chronologie.js of the MaX edition:
 * horizontal bars (lives of persons, dated events, works, organisations) on a min→max
 * axis, round ticks, axis repeated on top (sticky), epoch bands, filter by type.
 * Data: the rows of table#gs-timeline-data written by xslt/chronologie.xsl
 *   <tr data-type="person" data-start="-106" data-end="-43"><th><a href="person-000022.html">Ciceron</a></th>…
 * (the table stays in the page as the text alternative of the timeline).
 */
(function () {
    'use strict';

    var EPOCHS = [
        { label: 'Antiquité', from: -Infinity, to: 476 },
        { label: 'Moyen Âge', from: 476, to: 1492 },
        { label: 'Époque moderne', from: 1492, to: Infinity }
    ];
    var TYPE_NAMES = { person: 'Personnes', event: 'Événements', work: 'Œuvres', organization: 'Organisations' };

    function el(tag, cls, text) {
        var node = document.createElement(tag);
        if (cls) { node.className = cls; }
        if (text) { node.textContent = text; }
        return node;
    }

    function fmtYear(y) {
        if (y === 0) { return 'an 1'; }
        return y < 0 ? Math.abs(y) + ' av. J.-C.' : String(y);
    }

    function fmtRange(start, end) {
        if (start === end) { return fmtYear(start); }
        if (start < 0 && end < 0) { return Math.abs(start) + '–' + Math.abs(end) + ' av. J.-C.'; }
        return fmtYear(start) + '–' + fmtYear(end);
    }

    function niceTicks(min, max) {
        var span = max - min;
        var step = span > 2000 ? 500 : span > 1000 ? 250 : span > 300 ? 100 : span > 120 ? 50 : span > 60 ? 25 : 10;
        var ticks = [];
        for (var t = Math.ceil(min / step) * step; t <= max; t += step) { ticks.push(t); }
        return ticks;
    }

    function readItems() {
        var rows = document.querySelectorAll('#gs-timeline-data tbody tr');
        return Array.prototype.map.call(rows, function (tr) {
            var link = tr.querySelector('a');
            return {
                type: tr.getAttribute('data-type') || 'person',
                label: link ? link.textContent : '',
                url: link ? link.getAttribute('href') : '',
                start: parseInt(tr.getAttribute('data-start'), 10),
                end: parseInt(tr.getAttribute('data-end'), 10)
            };
        });
    }

    function render(container, items) {
        var undatedByType = {};
        var undatedTotal = 0;
        var valid = [];
        items.forEach(function (it) {
            if (!it.label) { return; }
            if (isNaN(it.start)) {
                undatedByType[it.type] = (undatedByType[it.type] || 0) + 1;
                undatedTotal += 1;
                return;
            }
            var end = isNaN(it.end) ? it.start : it.end;
            valid.push({ type: it.type, label: it.label, url: it.url, start: it.start, end: Math.max(it.start, end) });
        });
        if (!valid.length) {
            container.appendChild(el('p', 'gs-map-coverage', 'Aucune donnée chronologique disponible.'));
            return;
        }
        valid.sort(function (a, b) { return a.start - b.start; });

        var types = [];
        valid.forEach(function (it) { if (types.indexOf(it.type) < 0) { types.push(it.type); } });
        var current = 'all';
        var filters = el('div', 'gs-tl-filters');
        var count = el('span', 'gs-map-coverage');
        count.setAttribute('role', 'status');
        if (types.length > 1) {
            var label = el('label', 'gs-toolbar-label', 'Type');
            label.setAttribute('for', 'gs-tl-type');
            filters.appendChild(label);
            var sel = el('select', 'gs-toolbar-select');
            sel.id = 'gs-tl-type';
            var all = el('option', null, 'Tous');
            all.value = 'all';
            sel.appendChild(all);
            types.forEach(function (t) {
                var o = el('option', null, TYPE_NAMES[t] || t);
                o.value = t;
                sel.appendChild(o);
            });
            sel.addEventListener('change', function () { current = sel.value; draw(); });
            filters.appendChild(sel);
        }
        filters.appendChild(count);
        container.appendChild(filters);

        var axisTopWrap = el('div', 'gs-tl-axis-sticky');
        axisTopWrap.setAttribute('aria-hidden', 'true');
        var axisTop = el('div', 'gs-tl-axis gs-tl-scale');
        axisTopWrap.appendChild(axisTop);
        container.appendChild(axisTopWrap);
        var list = el('ul', 'gs-tl-list');
        list.setAttribute('aria-label', 'Frise chronologique');
        container.appendChild(list);
        var axisBottom = el('div', 'gs-tl-axis gs-tl-scale');
        axisBottom.setAttribute('aria-hidden', 'true');
        container.appendChild(axisBottom);

        function renderAxis(axis, ticks, min, span) {
            axis.textContent = '';
            ticks.forEach(function (t) {
                var s = el('span', null, fmtYear(t));
                s.style.left = (((t - min) / span) * 100) + '%';
                axis.appendChild(s);
            });
        }

        function renderDeco(ticks, min, max, span) {
            var deco = el('li', 'gs-tl-deco');
            deco.setAttribute('aria-hidden', 'true');
            var visible = EPOCHS.filter(function (e) { return e.from < max && e.to > min; });
            list.classList.toggle('gs-tl-has-epochs', visible.length > 1);
            if (visible.length > 1) {
                visible.forEach(function (e) {
                    var from = Math.max(e.from, min);
                    var to = Math.min(e.to, max);
                    var band = el('div', 'gs-tl-epoch' + (EPOCHS.indexOf(e) % 2 === 0 ? ' gs-tl-epoch-alt' : ''));
                    band.style.left = (((from - min) / span) * 100) + '%';
                    band.style.width = (((to - from) / span) * 100) + '%';
                    band.appendChild(el('span', 'gs-tl-epoch-label', e.label));
                    deco.appendChild(band);
                });
            }
            ticks.forEach(function (t) {
                var line = el('span', 'gs-tl-gridline');
                line.style.left = (((t - min) / span) * 100) + '%';
                deco.appendChild(line);
            });
            list.appendChild(deco);
        }

        function draw() {
            list.textContent = '';
            var subset = valid.filter(function (it) { return current === 'all' || it.type === current; });
            var undated = current === 'all' ? undatedTotal : (undatedByType[current] || 0);
            var undatedText = undated > 0 ? ' · + ' + undated + ' non datée' + (undated > 1 ? 's' : '') : '';
            if (!subset.length) {
                axisTop.textContent = '';
                axisBottom.textContent = '';
                count.textContent = '0 entrée' + undatedText;
                return;
            }
            var min = subset[0].start;
            var max = subset.reduce(function (m, it) { return Math.max(m, it.end); }, min);
            if (max === min) { max = min + 1; }
            var span = max - min;
            var ticks = niceTicks(min, max);
            renderAxis(axisTop, ticks, min, span);
            renderAxis(axisBottom, ticks, min, span);
            renderDeco(ticks, min, max, span);

            subset.forEach(function (it) {
                var row = el('li', 'gs-tl-item');
                var lab = el('span', 'gs-tl-label');
                var name = el('a', 'gs-tl-name', it.label);
                name.href = it.url;
                lab.appendChild(name);
                lab.appendChild(el('span', 'gs-tl-year', fmtRange(it.start, it.end)));
                lab.title = it.label + ' (' + fmtRange(it.start, it.end) + ')';
                row.appendChild(lab);
                var track = el('div', 'gs-tl-track');
                track.setAttribute('aria-hidden', 'true');
                var bar = el('span', 'gs-tl-bar gs-tl-' + it.type);
                bar.style.left = (((it.start - min) / span) * 100) + '%';
                bar.style.width = Math.max(0.4, ((it.end - it.start) / span) * 100) + '%';
                bar.title = lab.title;
                track.appendChild(bar);
                row.appendChild(track);
                list.appendChild(row);
            });
            count.textContent = subset.length + ' entrée' + (subset.length > 1 ? 's' : '') +
                ' · ' + fmtYear(min) + ' → ' + fmtYear(max) + undatedText;
        }
        draw();
    }

    function init() {
        var container = document.getElementById('gs-timeline');
        if (!container) { return; }
        var note = document.getElementById('gs-timeline-note');
        if (note) {
            note.textContent = 'La liste chronologique sous la frise en donne le contenu textuel.';
            note.className = 'visually-hidden';
        }
        render(container, readItems());
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
