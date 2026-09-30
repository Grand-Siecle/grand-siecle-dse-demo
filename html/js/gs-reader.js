/*
 * Grand Siecle reading page (xslt/editions.xsl), behaviour ported from the MaX edition
 * (ui/js/grand-siecle.js):
 *   (a) layer switch Original / Modernisé    (b) forme work toggle
 *   (c) word analysis + tooltip (lemma, POS and morphology in French)
 *   (d) entity popover (type, NER confidence, link to the register page)
 *   (e) NER confidence filter: all / high confidence / hidden   (g) entity legend
 *   (h) facsimile fallback when Gallica does not answer
 *   (j) page selector in the header (filled here) and left / right arrow keys
 * The toolbar is in the HTML (hidden without JavaScript); the default layer is set in the
 * HTML (html/@data-layer), so the text is readable without this script. Preferences are kept
 * in localStorage, as in MaX.
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

    /* ------------------------------------------------------------ (a) layers */
    var LAYER_KEY = 'layer.' + doc;

    function applyLayer(layer) {
        root.setAttribute('data-layer', layer);
        document.querySelectorAll('.gs-layer-btn').forEach(function (btn) {
            setPressed(btn, btn.getAttribute('data-value') === layer);
        });
    }

    /* ----------------------------------------------------- (c) word analysis */
    var POS_LABELS = {
        NOMcom: 'nom commun', NOMpro: 'nom propre',
        VER: 'verbe', VERcjg: 'verbe conjugué', VERinf: 'verbe (infinitif)',
        VERppe: 'participe passé', VERppa: 'participe présent',
        ADJqua: 'adjectif qualificatif', ADJind: 'adjectif indéfini',
        ADJcar: 'adjectif cardinal', ADJord: 'adjectif ordinal',
        ADJpos: 'adjectif possessif', ADJdem: 'adjectif démonstratif',
        ADVgen: 'adverbe', ADVneg: 'adverbe de négation', ADVint: 'adverbe interrogatif',
        PROper: 'pronom personnel', PROdem: 'pronom démonstratif',
        PROind: 'pronom indéfini', PROrel: 'pronom relatif',
        PROint: 'pronom interrogatif', PROpos: 'pronom possessif', PROimp: 'pronom impersonnel',
        DETdef: 'déterminant défini', DETndf: 'déterminant indéfini',
        DETdem: 'déterminant démonstratif', DETpos: 'déterminant possessif',
        DETind: 'déterminant indéfini', DETcar: 'déterminant cardinal',
        PRE: 'préposition', CONcoo: 'conjonction de coordination',
        CONsub: 'conjonction de subordination', INJ: 'interjection',
        ETR: 'mot étranger', ABR: 'abréviation',
        PONfbl: 'ponctuation faible', PONfrt: 'ponctuation forte'
    };
    var MSD_FR_KEYS = { 'NOMB.': 'nombre', 'GENRE': 'genre', 'MODE': 'mode', 'TEMPS': 'temps', 'PERS.': 'personne', 'CAS': 'cas' };
    var MSD_FR_VALUES = {
        s: 'singulier', p: 'pluriel', m: 'masculin', f: 'féminin',
        ind: 'indicatif', sub: 'subjonctif', cnd: 'conditionnel', imp: 'impératif',
        inf: 'infinitif', ppa: 'participe présent', ppe: 'participe passé',
        pst: 'présent', ipf: 'imparfait', fut: 'futur', psp: 'passé simple',
        pqp: 'plus-que-parfait', i: 'régime indirect', j: 'régime direct',
        n: 'nominatif', r: 'régime', '1': '1ʳᵉ pers.', '2': '2ᵉ pers.', '3': '3ᵉ pers.'
    };
    var MSD_LAT_KEYS = { Case: 'cas', Numb: 'nombre', Gend: 'genre', Mood: 'mode', Tense: 'temps', Voice: 'voix', Person: 'personne', Deg: 'degré' };
    var MSD_LAT_VALUES = {
        Nom: 'nominatif', Gen: 'génitif', Dat: 'datif', Acc: 'accusatif', Abl: 'ablatif', Voc: 'vocatif', Loc: 'locatif',
        Sing: 'singulier', Plur: 'pluriel', Masc: 'masculin', Fem: 'féminin', Neut: 'neutre', Com: 'commun',
        MascNeut: 'masculin/neutre', MascFem: 'masculin/féminin',
        Ind: 'indicatif', Sub: 'subjonctif', Imp: 'impératif', Inf: 'infinitif', Par: 'participe', Ger: 'gérondif',
        Adj: 'adjectif verbal', Sup: 'supin', SupUm: 'supin en -um',
        Pres: 'présent', Impa: 'imparfait', Fut: 'futur', Perf: 'parfait', Pqp: 'plus-que-parfait',
        PeriFut: 'futur périphrastique', FutAnt: 'futur antérieur',
        Act: 'actif', Pass: 'passif', Dep: 'déponent', Pos: 'positif', Comp: 'comparatif', Superl: 'superlatif'
    };
    /* values whose meaning depends on the key (Case=Ind is not Mood=Ind...) */
    var MSD_OVERRIDES = { 'Case=Ind': 'indéclinable', 'Deg=Sup': 'superlatif', 'GENRE=n': 'neutre', 'MODE=con': 'conditionnel', 'PERS.=0': 'impersonnel' };

    function decodeMsd(msd) {
        if (!msd || msd === 'MORPH=empty' || msd === '_') { return ''; }
        var latin = /(Case|Numb|Mood|Tense|Gend|Voice)=/.test(msd);
        var keys = latin ? MSD_LAT_KEYS : MSD_FR_KEYS;
        var values = latin ? MSD_LAT_VALUES : MSD_FR_VALUES;
        return msd.split('|').map(function (pair) {
            var i = pair.indexOf('=');
            if (i < 0) { return pair; }
            var k = pair.slice(0, i), v = pair.slice(i + 1);
            if (v === 'empty' || v === '_' || v === '') { return ''; }
            var label = keys[k] || k.toLowerCase();
            return label + ' ' + (MSD_OVERRIDES[k + '=' + v] || values[v] || v);
        }).filter(Boolean).join(' · ');
    }

    /* displayable lemma: no tool marker (@card...), no letterless noise, "sum1" -> "sum" */
    function displayLemma(lemma) {
        if (!lemma || lemma.charAt(0) === '@' || !/[a-zà-öø-ÿœæ]/i.test(lemma)) { return ''; }
        return lemma.replace(/(\D)\d+$/, '$1');
    }

    var lingBtn = null;
    var lingStatus = null;

    function setLing(on) {
        document.body.classList.toggle('gs-ling-on', on);
        if (lingBtn) { setPressed(lingBtn, on); }
        lsSet('ling', on ? 'on' : 'off');
        if (lingStatus) { lingStatus.textContent = ''; }
        if (!on) { hideTooltip(); }
        /* word annotations only exist in the original layer */
        if (on && root.getAttribute('data-layer') === 'reg') {
            applyLayer('orig');
            lsSet(LAYER_KEY, 'orig');
            if (lingStatus) { lingStatus.textContent = 'affichée sur la couche originale'; }
        }
    }

    function placeNear(box, target) {
        var rect = target.getBoundingClientRect();
        box.style.visibility = 'hidden';
        box.hidden = false;
        var left = rect.left + window.scrollX;
        var maxLeft = window.scrollX + document.documentElement.clientWidth - box.offsetWidth - 12;
        box.style.top = (rect.bottom + window.scrollY + 6) + 'px';
        box.style.left = Math.max(4, Math.min(left, maxLeft)) + 'px';
        box.style.visibility = '';
    }

    var tooltip = null;
    function hideTooltip() { if (tooltip) { tooltip.hidden = true; } }

    function showWordTooltip(w) {
        var lemma = displayLemma(w.getAttribute('data-lemma'));
        var pos = w.getAttribute('data-pos') || '';
        var msd = decodeMsd(w.getAttribute('data-msd'));
        if (!lemma && !pos && !msd) { return; }
        if (!tooltip) {
            tooltip = document.createElement('div');
            tooltip.className = 'gs-tooltip';
            tooltip.setAttribute('role', 'tooltip');
            tooltip.hidden = true;
            document.body.appendChild(tooltip);
        }
        tooltip.textContent = '';
        var l1 = document.createElement('div');
        l1.className = 'gs-tt-line1';
        l1.textContent = lemma || w.textContent.trim();
        if (pos) {
            var p = document.createElement('span');
            p.className = 'gs-tt-pos';
            p.textContent = ' (' + (POS_LABELS[pos] || pos) + ')';
            l1.appendChild(p);
        }
        tooltip.appendChild(l1);
        if (msd) {
            var l2 = document.createElement('div');
            l2.className = 'gs-tt-msd';
            l2.textContent = msd;
            tooltip.appendChild(l2);
        }
        placeNear(tooltip, w);
    }

    /* ------------------------------------------------------ (d) entity popover */
    var TYPE_LABELS = {
        person: 'Personne', place: 'Lieu', organization: 'Organisation', org: 'Organisation',
        work: 'Œuvre', event: 'Événement', artwork: 'Objet / œuvre d’art',
        material: 'Matériau', technique: 'Technique', date: 'Date'
    };
    var CERT_LABELS = { high: 'confiance haute', mid: 'confiance moyenne', low: 'confiance faible' };
    var popover = null;
    var popHideTimer = null;

    function hidePopover() { if (popover) { popover.hidden = true; } }
    function schedulePopHide() {
        if (popHideTimer) { clearTimeout(popHideTimer); }
        popHideTimer = setTimeout(hidePopover, 250);
    }

    function showEntityPopover(ent) {
        if (popHideTimer) { clearTimeout(popHideTimer); popHideTimer = null; }
        if (!popover) {
            popover = document.createElement('div');
            popover.className = 'gs-popover';
            popover.hidden = true;
            popover.addEventListener('mouseenter', function () {
                if (popHideTimer) { clearTimeout(popHideTimer); popHideTimer = null; }
            });
            popover.addEventListener('mouseleave', schedulePopHide);
            document.body.appendChild(popover);
        }
        var type = ent.getAttribute('data-type') || '';
        var cert = ent.getAttribute('data-cert') || '';
        popover.style.setProperty('--gs-type', 'var(--gs-type-' + (type === 'org' ? 'organization' : type) + ')');
        popover.textContent = '';
        var label = document.createElement('div');
        label.className = 'gs-pop-label';
        label.textContent = ent.textContent.replace(/\s+/g, ' ').trim();
        popover.appendChild(label);
        var meta = document.createElement('div');
        var badge = document.createElement('span');
        badge.className = 'gs-pop-type';
        badge.textContent = TYPE_LABELS[type] || type || 'Entité';
        meta.appendChild(badge);
        if (cert) {
            var c = document.createElement('span');
            c.className = 'gs-pop-cert';
            c.textContent = CERT_LABELS[cert] || ('confiance : ' + cert);
            meta.appendChild(c);
        }
        popover.appendChild(meta);
        var href = ent.getAttribute('href');
        if (href) {
            var a = document.createElement('a');
            a.className = 'gs-pop-link';
            a.href = href;
            a.textContent = 'Voir la fiche';
            popover.appendChild(a);
        } else {
            var un = document.createElement('div');
            un.className = 'gs-pop-cert';
            un.textContent = 'Entité non réconciliée (sans fiche)';
            popover.appendChild(un);
        }
        placeNear(popover, ent);
    }

    /* --------------------------------------------- (e) NER confidence filter */
    function applyNerMode(mode) {
        document.body.classList.toggle('gs-ner-high', mode === 'high');
        document.body.classList.toggle('gs-ent-off', mode === 'off');
        if (mode !== 'all') { hidePopover(); }
    }
    /* entity neutralised by the current filter (CSS already disables pointer events) */
    function entBlocked(ent) {
        if (document.body.classList.contains('gs-ent-off')) { return true; }
        var cert = ent.getAttribute('data-cert');
        return document.body.classList.contains('gs-ner-high') && (cert === 'mid' || cert === 'low');
    }

    /* --------------------------------------------------------------- (g) legend */
    var LEGEND_TYPES = [
        ['person', 'Personne'], ['place', 'Lieu'], ['organization', 'Organisation'],
        ['work', 'Œuvre'], ['event', 'Événement'], ['technique', 'Technique'],
        ['date', 'Date'], ['artwork', 'Objet'], ['material', 'Matériau']
    ];
    var LEGEND_LINES = [
        ['gs-legend-line-solid', 'filet plein — haute'],
        ['gs-legend-line-dotted', 'pointillé — moyenne'],
        ['gs-legend-line-faded', 'pointillé estompé — faible']
    ];

    function buildLegend() {
        var det = document.createElement('details');
        det.className = 'gs-legend';
        var sum = document.createElement('summary');
        sum.textContent = 'Légende';
        det.appendChild(sum);
        var panel = document.createElement('div');
        panel.className = 'gs-legend-panel';
        function title(text) {
            var t = document.createElement('div');
            t.className = 'gs-legend-title';
            t.textContent = text;
            panel.appendChild(t);
        }
        function item(sample, text) {
            var it = document.createElement('div');
            it.className = 'gs-legend-item';
            sample.setAttribute('aria-hidden', 'true');
            it.appendChild(sample);
            it.appendChild(document.createTextNode(text));
            panel.appendChild(it);
        }
        title('Types d’entités');
        LEGEND_TYPES.forEach(function (pair) {
            var sw = document.createElement('span');
            sw.className = 'gs-legend-swatch';
            sw.style.setProperty('--gs-type', 'var(--gs-type-' + pair[0] + ')');
            item(sw, pair[1]);
        });
        title('Confiance de détection');
        LEGEND_LINES.forEach(function (pair) {
            var line = document.createElement('span');
            line.className = 'gs-legend-line ' + pair[0];
            item(line, pair[1]);
        });
        det.appendChild(panel);
        return det;
    }

    /* ------------------------------------------------------------------ init */
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

        lingBtn = document.querySelector('.gs-ling-btn');
        lingStatus = document.querySelector('.gs-ling-status');
        if (lingBtn) {
            if (lsGet('ling') === 'on') { setLing(true); } else { setPressed(lingBtn, false); }
            lingBtn.addEventListener('click', function () {
                setLing(!document.body.classList.contains('gs-ling-on'));
            });
        }

        var ner = document.getElementById('gs-ner-select');
        if (ner) {
            var storedNer = lsGet('ner');
            ner.value = (storedNer === 'high' || storedNer === 'off') ? storedNer : 'all';
            applyNerMode(ner.value);
            ner.addEventListener('change', function () {
                applyNerMode(ner.value);
                lsSet('ner', ner.value);
            });
        }

        var toolbar = document.querySelector('.gs-doc-toolbar');
        if (toolbar) { toolbar.appendChild(buildLegend()); }

        /* page selector: the HTML lists the current page only */
        document.querySelectorAll('.gs-page-select').forEach(function (sel) {
            var id = sel.getAttribute('data-doc');
            var max = parseInt(sel.getAttribute('data-max'), 10);
            var current = sel.value;
            if (id && max > 1) {
                var frag = document.createDocumentFragment();
                for (var i = 1; i <= max; i += 1) {
                    var o = document.createElement('option');
                    o.value = id + '-page-' + i + '.html';
                    o.textContent = 'p. ' + i;
                    frag.appendChild(o);
                }
                sel.textContent = '';
                sel.appendChild(frag);
                sel.value = current;
            }
            sel.addEventListener('change', function () {
                if (sel.value) { window.location.href = sel.value; }
            });
        });

        /* facsimile fallback when Gallica does not answer */
        document.querySelectorAll('.page-facsimile img').forEach(function (img) {
            function fail() {
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
            }
            if (img.complete && img.naturalWidth === 0 && img.getAttribute('src')) { fail(); }
            else { img.addEventListener('error', fail); }
        });
    });

    /* delegated listeners: popover, word tooltip */
    document.addEventListener('mouseover', function (ev) {
        var t = ev.target;
        if (!t.closest) { return; }
        var ent = t.closest('.ent');
        if (ent && !entBlocked(ent)) { showEntityPopover(ent); return; }
        if (document.body.classList.contains('gs-ling-on')) {
            var w = t.closest('.w');
            if (w) { showWordTooltip(w); }
        }
    });
    document.addEventListener('mouseout', function (ev) {
        if (!ev.target.closest) { return; }
        if (ev.target.closest('.ent')) { schedulePopHide(); }
        if (ev.target.closest('.w')) { hideTooltip(); }
    });
    document.addEventListener('focusin', function (ev) {
        var ent = ev.target.closest ? ev.target.closest('.ent') : null;
        if (ent && !entBlocked(ent)) { showEntityPopover(ent); }
    });
    document.addEventListener('focusout', function () { hideTooltip(); schedulePopHide(); });
    document.addEventListener('click', function (ev) {
        var ent = ev.target.closest ? ev.target.closest('.ent') : null;
        if (ent && entBlocked(ent)) { ev.preventDefault(); }
    });
    window.addEventListener('scroll', function () { hideTooltip(); hidePopover(); }, { passive: true });

    /* keyboard: Escape closes the bubbles; left / right arrows change page */
    document.addEventListener('keydown', function (ev) {
        if (ev.key === 'Escape') { hideTooltip(); hidePopover(); return; }
        if (ev.key !== 'ArrowLeft' && ev.key !== 'ArrowRight') { return; }
        if (ev.ctrlKey || ev.metaKey || ev.altKey || ev.shiftKey) { return; }
        var t = ev.target;
        if (t && (/^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(t.tagName) || t.isContentEditable)) { return; }
        var link = document.querySelector(ev.key === 'ArrowLeft' ? 'a.gs-page-prev' : 'a.gs-page-next');
        if (link) { window.location.href = link.href; }
    });
}());
