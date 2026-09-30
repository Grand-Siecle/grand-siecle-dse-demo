<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): map of the cited places (carte.html), as in the MaX edition
    (fragments/fr/carte.frag.html + ui/js/carte.js): Leaflet, OpenStreetMap tiles, one
    circle per geolocated place, radius growing with the mentions in the texts present.
    The data of the map is the table written here (one row per place with coordinates,
    data-lat / data-lon / data-mentions), read by js/gs-carte.js: the table is also the
    text alternative of the map (as the template's make_map_and_table.js reads its table).
    Input document: data/indices/places.xml (only the places of the perimeter are shown).
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/registres.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="no" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <xsl:variable name="places" as="element()*">
            <xsl:perform-sort select="gs:entries($gs:types[@prefix = 'place'])[count(tokenize(normalize-space(tei:location[1]/tei:geo[1]), ' ')[. castable as xs:double]) = 2]">
                <xsl:sort select="gs:sort-key(.)" lang="fr"/>
            </xsl:perform-sort>
        </xsl:variable>
        <xsl:call-template name="gs:page">
            <xsl:with-param name="title" select="'Carte des lieux'"/>
            <xsl:with-param name="body_class" select="'gs-carte-page'"/>
            <xsl:with-param name="css" select="('vendor/leaflet/leaflet.css', 'css/visualisations.css')"/>
            <xsl:with-param name="content">
                <div id="gs-carte" class="gs-map-wrap gs-index-page">
                    <p class="gs-section-kicker">Explorer</p>
                    <h1 class="gs-section-title">Carte des lieux</h1>
                    <p class="gs-section-intro">Les lieux cités dans le corpus et géolocalisés lors de la
                        réconciliation avec Wikidata. Chaque marqueur renvoie à la fiche du lieu dans les
                        registres d'autorité.</p>
                    <div id="gs-map" role="region" aria-label="Carte interactive des lieux (la liste qui suit en donne le contenu)"></div>
                    <p class="gs-map-coverage" id="gs-map-status" role="status">
                        <xsl:value-of select="count($places)"/> lieux géolocalisés sur <xsl:value-of select="count(gs:entries($gs:types[@prefix = 'place']))"/> lieux cités.
                        La carte interactive nécessite JavaScript ; la liste ci-dessous en donne le contenu.</p>
                    <details class="gs-alt-list">
                        <summary>Liste des lieux de la carte (<xsl:value-of select="count($places)"/>)</summary>
                        <div class="gs-alt-scroll">
                            <table class="gs-alt-table" id="gs-map-data">
                                <caption class="visually-hidden">Lieux géolocalisés cités dans les <xsl:value-of select="gs:number-fr(count($gs:doc-ids), false())"/> documents</caption>
                                <thead>
                                    <tr>
                                        <th scope="col">Lieu</th>
                                        <th scope="col">Pays</th>
                                        <th scope="col">Mentions (démo)</th>
                                        <th scope="col">Latitude</th>
                                        <th scope="col">Longitude</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <xsl:for-each select="$places">
                                        <xsl:variable name="geo" select="tokenize(normalize-space(tei:location[1]/tei:geo[1]), ' ')"/>
                                        <tr id="{@xml:id}" data-lat="{$geo[1]}" data-lon="{$geo[2]}" data-mentions="{gs:demo-mentions(.)}">
                                            <th scope="row"><a href="{@xml:id}.html"><xsl:value-of select="gs:label(.)"/></a></th>
                                            <td><xsl:value-of select="normalize-space(tei:country[1])"/></td>
                                            <td class="gs-num"><xsl:value-of select="gs:demo-mentions(.)"/></td>
                                            <td class="gs-num"><xsl:value-of select="$geo[1]"/></td>
                                            <td class="gs-num"><xsl:value-of select="$geo[2]"/></td>
                                        </tr>
                                    </xsl:for-each>
                                </tbody>
                            </table>
                        </div>
                    </details>
                    <p class="gs-map-credit">Fond de carte : tuiles <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>
                        (tile.openstreetmap.org, chargées depuis les serveurs de la fondation OpenStreetMap à l'affichage de la carte).</p>
                </div>
            </xsl:with-param>
            <xsl:with-param name="scripts">
                <script src="vendor/leaflet/leaflet.js"></script>
                <script src="js/gs-carte.js"></script>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
</xsl:stylesheet>
