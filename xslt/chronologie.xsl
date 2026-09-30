<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): timeline (chronologie.html), as in the MaX edition
    (fragments/fr/chronologie.frag.html + ui/js/chronologie.js, data of timeline.json in
    scripts/build-entities.mjs): lives of the cited persons (birth -> death), dated events,
    works with a publication year, organisations with a foundation year.
    The data of the timeline is the table written here (data-type / data-start / data-end),
    read by js/gs-chronologie.js; the table is also the text alternative of the timeline.
    Input document: any (the nine data/indices files are read through $gs:indices).
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

    <xsl:variable name="type_names" as="element()*">
        <t key="person">Personne</t><t key="event">Événement</t><t key="work">Œuvre</t><t key="organization">Organisation</t>
    </xsl:variable>

    <xsl:function name="gs:sorted" as="element()*">
        <xsl:param name="prefix" as="xs:string"/>
        <xsl:perform-sort select="gs:entries($gs:types[@prefix = $prefix])">
            <xsl:sort select="gs:sort-key(.)" lang="fr"/>
        </xsl:perform-sort>
    </xsl:function>

    <xsl:template match="/">
        <!-- items in the order of build-entities.mjs: persons, events, works, organisations -->
        <xsl:variable name="items" as="element(item)*">
            <xsl:for-each select="gs:sorted('person')">
                <xsl:if test="exists((gs:birth(.), gs:death(.)))">
                    <item id="{@xml:id}" type="person" start="{gs:birth(.)}" end="{gs:death(.)}" label="{gs:label(.)}"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:for-each select="gs:sorted('event')">
                <xsl:variable name="when" select="gs:event-date(., 'when')"/>
                <xsl:variable name="start" select="($when, gs:event-date(., 'notBefore'))[1]"/>
                <xsl:variable name="end" select="($when, gs:event-date(., 'notAfter'))[1]"/>
                <xsl:if test="exists(($start, $end))">
                    <item id="{@xml:id}" type="event" start="{$start}" end="{$end}" label="{gs:label(.)}"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:for-each select="gs:sorted('work')[exists(gs:pub-year(.))]">
                <item id="{@xml:id}" type="work" start="{gs:pub-year(.)}" end="{gs:pub-year(.)}" label="{gs:label(.)}"/>
            </xsl:for-each>
            <xsl:for-each select="gs:sorted('org')[exists(gs:foundation(.))]">
                <item id="{@xml:id}" type="organization" start="{gs:foundation(.)}" end="{gs:foundation(.)}" label="{gs:label(.)}"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="sorted" as="element(item)*">
            <xsl:perform-sort select="$items">
                <xsl:sort select="xs:integer((@start[. != ''], @end[. != ''], 0)[1])" data-type="number"/>
            </xsl:perform-sort>
        </xsl:variable>

        <xsl:call-template name="gs:page">
            <xsl:with-param name="title" select="'Chronologie'"/>
            <xsl:with-param name="body_class" select="'gs-chronologie-page'"/>
            <xsl:with-param name="css" select="'css/visualisations.css'"/>
            <xsl:with-param name="content">
                <div id="gs-chronologie" class="gs-index-page">
                    <p class="gs-section-kicker">Explorer</p>
                    <h1 class="gs-section-title">Chronologie</h1>
                    <p class="gs-section-intro">Frise des vies des personnes citées dans le corpus
                        (naissance → décès) et des événements datés, d'après les données normalisées des
                        registres d'autorité.</p>
                    <div id="gs-timeline" aria-describedby="gs-timeline-note">
                        <p class="gs-map-coverage" id="gs-timeline-note">La frise interactive nécessite JavaScript ;
                            la liste ci-dessous en donne le contenu (<xsl:value-of select="count($sorted)"/> entrées).</p>
                    </div>
                    <details class="gs-alt-list">
                        <summary>Liste chronologique (<xsl:value-of select="count($sorted)"/> entrées)</summary>
                        <div class="gs-alt-scroll">
                            <table class="gs-alt-table" id="gs-timeline-data">
                                <caption class="visually-hidden">Personnes, événements, œuvres et organisations datés, par date de début</caption>
                                <thead>
                                    <tr>
                                        <th scope="col">Entité</th>
                                        <th scope="col">Type</th>
                                        <th scope="col">Début</th>
                                        <th scope="col">Fin</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <xsl:for-each select="$sorted">
                                        <tr data-type="{@type}" data-start="{@start}" data-end="{@end}">
                                            <th scope="row"><a href="{@id}.html"><xsl:value-of select="@label"/></a></th>
                                            <td><xsl:value-of select="$type_names[@key = current()/@type]"/></td>
                                            <td><xsl:value-of select="if (@start != '') then gs:disp-year(xs:integer(@start)) else '—'"/></td>
                                            <td><xsl:value-of select="if (@end != '') then gs:disp-year(xs:integer(@end)) else '—'"/></td>
                                        </tr>
                                    </xsl:for-each>
                                </tbody>
                            </table>
                        </div>
                    </details>
                </div>
            </xsl:with-param>
            <xsl:with-param name="scripts">
                <script src="js/gs-chronologie.js"></script>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
</xsl:stylesheet>
