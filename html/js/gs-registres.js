/**
 * gs-registres.js — Grand Siècle, démonstration DSE (J4)
 *
 * Filter of the A–Z index pages (list*.html), port of registres-browse.js of the
 * MaX edition. No dependency, no request: everything is read from the list written
 * by xslt/listentity.xsl:
 *   #index-{slug}[data-type][data-facet-{name}="Label"]   container + facet labels
 *   li.gs-index-item[data-names="a|b"][data-conf][data-f-{name}="v1|v2"]
 * Adds: instant search (labels, sort form, variants; case and accent insensitive),
 * one select per facet (values seen at least twice, 30 max) + reconciliation
 * confidence, result counter, reset, empty letters hidden and dimmed in the A–Z bar,
 * state kept in location.hash (#q=…&conf=…), link to the full-text search when
 * nothing matches. Without JavaScript the page is the plain A–Z list.
 */
(function () {
  'use strict';

  var CONF_LABELS = { high: 'confiance forte', medium: 'confiance moyenne', low: 'confiance faible', none: 'non réconciliée' };

  function fold(s) {
    return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  }

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'text') e.textContent = attrs[k];
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) { e.appendChild(c); });
    return e;
  }

  function values(li, name) {
    var v = li.getAttribute('data-f-' + name);
    return v ? v.split('|').filter(Boolean) : [];
  }

  function readHash() {
    var h = location.hash.replace(/^#/, '');
    var state = {};
    if (h.indexOf('=') === -1) return state; // A–Z anchor (#az-P), not a state
    h.split('&').forEach(function (pair) {
      var i = pair.indexOf('=');
      if (i === -1) return;
      try { state[decodeURIComponent(pair.slice(0, i))] = decodeURIComponent(pair.slice(i + 1)); } catch (e) { /* ignored */ }
    });
    return state;
  }

  function writeHash(state) {
    var parts = Object.keys(state).filter(function (k) { return state[k]; })
      .map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(state[k]); });
    if (parts.length) history.replaceState(null, '', '#' + parts.join('&'));
    else if (location.hash.indexOf('=') !== -1) history.replaceState(null, '', location.pathname + location.search);
  }

  function init() {
    var box = document.querySelector('.gs-index-list[data-type]');
    if (!box) return;
    var rows = Array.prototype.map.call(box.querySelectorAll('li.gs-index-item'), function (li) {
      return { li: li, text: fold(li.getAttribute('data-names') || li.textContent) };
    });
    if (!rows.length) return;
    var groups = Array.prototype.map.call(box.querySelectorAll('.gs-az-group'), function (section) {
      return { section: section, az: document.querySelector('.gs-az a[href="#' + section.id + '"]') };
    });

    var toolbar = el('div', { 'class': 'gs-browse-toolbar', role: 'search', 'aria-label': 'Filtrer l’index' });
    var search = el('input', { type: 'search', id: 'gs-browse-q', placeholder: 'Rechercher…', autocomplete: 'off' });
    toolbar.appendChild(el('div', { 'class': 'gs-browse-field' }, [
      el('label', { 'for': 'gs-browse-q', text: 'Recherche' }), search]));

    var selects = [];
    function addSelect(key, label, options, getValues, optionLabel) {
      if (!options.length) return;
      var id = 'gs-browse-' + key;
      var sel = el('select', { id: id });
      sel.appendChild(el('option', { value: '', text: label + ' — toutes' }));
      options.forEach(function (o) {
        sel.appendChild(el('option', { value: o.value, text: (optionLabel ? optionLabel(o.value) : o.value) + ' (' + o.count + ')' }));
      });
      toolbar.appendChild(el('div', { 'class': 'gs-browse-field' }, [el('label', { 'for': id, text: label }), sel]));
      sel.addEventListener('change', apply);
      selects.push({ key: key, sel: sel, getValues: getValues });
    }

    // facets declared by the page, values seen at least twice (as in MaX)
    Array.prototype.forEach.call(box.attributes, function (attr) {
      var m = attr.name.match(/^data-facet-(.+)$/);
      if (!m) return;
      var name = m[1];
      var counts = {};
      rows.forEach(function (r) { values(r.li, name).forEach(function (v) { counts[v] = (counts[v] || 0) + 1; }); });
      var options = Object.keys(counts).filter(function (v) { return counts[v] >= 2; })
        .sort(function (a, b) { return counts[b] - counts[a] || a.localeCompare(b, 'fr'); })
        .slice(0, 30).map(function (v) { return { value: v, count: counts[v] }; });
      addSelect(name, attr.value, options, function (li) { return values(li, name); });
    });

    // reconciliation confidence, for every register
    var conf = {};
    rows.forEach(function (r) { var c = r.li.getAttribute('data-conf') || 'none'; conf[c] = (conf[c] || 0) + 1; });
    var confOptions = ['high', 'medium', 'low', 'none'].filter(function (c) { return conf[c]; })
      .map(function (c) { return { value: c, count: conf[c] }; });
    if (confOptions.length > 1) {
      addSelect('conf', 'Réconciliation', confOptions,
        function (li) { return [li.getAttribute('data-conf') || 'none']; },
        function (v) { return CONF_LABELS[v]; });
      selects[selects.length - 1].sel.options[0].textContent = 'Confiance — toutes';
    }

    var reset = el('button', { type: 'button', 'class': 'gs-browse-reset', text: 'Réinitialiser' });
    toolbar.appendChild(reset);
    var counter = el('span', { 'class': 'gs-browse-count', role: 'status', 'aria-live': 'polite' });
    toolbar.appendChild(counter);
    var empty = el('p', { 'class': 'gs-browse-empty gs-browse-hidden' });
    box.insertBefore(toolbar, box.firstChild);
    box.insertBefore(empty, toolbar.nextSibling);

    var ready = false;
    function apply() {
      var raw = search.value.trim();
      var q = fold(raw);
      var any = Boolean(q);
      var state = { q: raw };
      selects.forEach(function (s) { state[s.key] = s.sel.value; if (s.sel.value) any = true; });
      var visible = 0;
      rows.forEach(function (r) {
        var ok = !q || r.text.indexOf(q) !== -1;
        for (var i = 0; ok && i < selects.length; i++) {
          var s = selects[i];
          if (s.sel.value && s.getValues(r.li).indexOf(s.sel.value) === -1) ok = false;
        }
        r.li.classList.toggle('gs-browse-hidden', !ok);
        if (ok) visible++;
      });
      groups.forEach(function (g) {
        var off = any && !g.section.querySelector('li:not(.gs-browse-hidden)');
        g.section.classList.toggle('gs-browse-hidden', off);
        if (g.az) {
          g.az.classList.toggle('gs-az-off', off);
          if (off) g.az.setAttribute('aria-disabled', 'true'); else g.az.removeAttribute('aria-disabled');
        }
      });
      counter.textContent = visible + ' / ' + rows.length + ' résultat' + (visible > 1 ? 's' : '');
      empty.textContent = 'Aucun résultat pour ces critères.';
      if (visible === 0 && raw) {
        empty.appendChild(document.createTextNode(' — '));
        empty.appendChild(el('a', { href: 'search.html?q=' + encodeURIComponent(raw), text: 'chercher « ' + raw + ' » dans toute l’édition →' }));
      }
      empty.classList.toggle('gs-browse-hidden', visible !== 0);
      if (ready) writeHash(state);
    }

    var debounce;
    search.addEventListener('input', function () { clearTimeout(debounce); debounce = setTimeout(apply, 150); });
    reset.addEventListener('click', function () {
      search.value = '';
      selects.forEach(function (s) { s.sel.value = ''; });
      apply();
      search.focus();
    });

    var initial = readHash();
    if (initial.q) search.value = initial.q;
    selects.forEach(function (s) { if (initial[s.key]) s.sel.value = initial[s.key]; });
    apply();
    ready = true;
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
