/**
 * gs-carte.js — Grand Siècle, démonstration DSE (J4)
 * Map of the cited places, port of ui/js/carte.js of the MaX edition (Leaflet 1.9.4
 * from html/vendor, OpenStreetMap tiles, same markers, popups and framing).
 * Data: the rows of table#gs-map-data written by xslt/carte.xsl
 *   <tr id="place-000001" data-lat data-lon data-mentions><th><a href="place-000001.html">Rome</a></th><td>Italie</td>…
 * (the table stays in the page as the text alternative of the map).
 * carte.html#place-000001 opens the popup of that place (link "voir sur la carte" of the entity pages).
 */
(function () {
    'use strict';

    /* initial frame: wider Europe (odd geocodings — Vistula in Indiana, Mantua in Utah —
       stay reachable by zooming out) */
    var EUROPE = { latMin: 34, latMax: 62, lonMin: -11, lonMax: 33 };

    /* deterministic spiral for duplicate coordinates (e.g. "Gallia" and "Gaules"):
       a few hundred metres, every marker can be selected */
    function spread(lat, lon, n) {
        if (n === 0) { return [lat, lon]; }
        var angle = n * 2.399963;
        var r = 0.006 * Math.sqrt(n);
        return [lat + r * Math.cos(angle), lon + r * Math.sin(angle) / Math.cos(lat * Math.PI / 180)];
    }

    function popupContent(p) {
        var wrap = document.createElement('div');
        wrap.className = 'gs-map-popup';
        var badge = document.createElement('span');
        badge.className = 'gs-map-popup-type';
        badge.textContent = 'Lieu';
        wrap.appendChild(badge);
        var name = document.createElement('a');
        name.href = p.url;
        name.textContent = p.label;
        name.className = 'gs-map-popup-name';
        wrap.appendChild(name);
        if (p.mentions > 0) {
            var mentions = document.createElement('span');
            mentions.className = 'gs-map-popup-mentions';
            mentions.textContent = p.mentions + ' mention' + (p.mentions > 1 ? 's' : '') + ' dans les documents de la démo';
            wrap.appendChild(mentions);
        }
        if (p.country) {
            var country = document.createElement('em');
            country.className = 'gs-map-popup-country';
            country.textContent = p.country;
            wrap.appendChild(country);
        }
        return wrap;
    }

    function readPlaces() {
        var rows = document.querySelectorAll('#gs-map-data tbody tr[data-lat]');
        return Array.prototype.map.call(rows, function (tr) {
            var link = tr.querySelector('a');
            var country = tr.querySelector('td');
            return {
                id: tr.id,
                lat: parseFloat(tr.getAttribute('data-lat')),
                lon: parseFloat(tr.getAttribute('data-lon')),
                mentions: parseInt(tr.getAttribute('data-mentions'), 10) || 0,
                label: link ? link.textContent : tr.id,
                url: link ? link.getAttribute('href') : tr.id + '.html',
                country: country ? country.textContent : ''
            };
        });
    }

    function init() {
        var container = document.getElementById('gs-map');
        var status = document.getElementById('gs-map-status');
        if (!container) { return; }
        if (typeof L === 'undefined') {
            if (status) { status.textContent = 'La carte n’a pas pu être chargée (composant cartographique absent). Les lieux restent consultables dans la liste ci-dessous.'; }
            return;
        }
        var placeColor = (getComputedStyle(document.documentElement).getPropertyValue('--gs-type-place') || '').trim() || '#3A6B4A';

        var map = L.map(container).setView([46.6, 2.2], 5);
        var tiles = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 18,
            attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(map);

        /* tiles unavailable: one message, the places stay clickable */
        var tileErrorShown = false;
        tiles.on('tileerror', function () {
            if (tileErrorShown || !status) { return; }
            tileErrorShown = true;
            status.textContent += ' Fond de carte momentanément indisponible — les lieux restent cliquables.';
        });

        var places = readPlaces();
        var seen = {};
        var europe = [];
        var markers = {};
        places.forEach(function (p) {
            if (isNaN(p.lat) || isNaN(p.lon)) { return; }
            var key = p.lat.toFixed(5) + ',' + p.lon.toFixed(5);
            var n = seen[key] || 0;
            seen[key] = n + 1;
            var pos = spread(p.lat, p.lon, n);
            var m = Math.max(1, p.mentions);
            var marker = L.circleMarker(pos, {
                radius: 5 + 2 * Math.sqrt(m),
                fillColor: placeColor,
                color: '#FEFCF7',
                weight: 1.5,
                fillOpacity: 0.85
            }).addTo(map);
            marker.bindPopup(popupContent(p));
            marker.bindTooltip(p.label, { direction: 'top', offset: [0, -4] });
            markers[p.id] = marker;
            /* only the points of the European frame set the initial view */
            if (p.lat >= EUROPE.latMin && p.lat <= EUROPE.latMax && p.lon >= EUROPE.lonMin && p.lon <= EUROPE.lonMax) {
                europe.push(pos);
            }
        });
        if (europe.length) { map.fitBounds(europe, { padding: [30, 30], maxZoom: 8 }); }
        if (status) {
            status.textContent = Object.keys(markers).length + ' lieux géolocalisés affichés · taille des marqueurs proportionnelle au nombre de mentions';
        }

        /* carte.html#place-000001: centre on that place and open its popup */
        function focusHash() {
            var id = decodeURIComponent(location.hash.replace(/^#/, ''));
            var marker = markers[id];
            if (!marker) { return; }
            map.setView(marker.getLatLng(), Math.max(map.getZoom(), 7));
            marker.openPopup();
            container.scrollIntoView({ block: 'center' });
        }
        focusHash();
        window.addEventListener('hashchange', focusHash);

        /* white tiles if the container was resized during load */
        setTimeout(function () { map.invalidateSize(); }, 300);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
