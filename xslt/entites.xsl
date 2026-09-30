<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): hub of the nine registers (entites.html), same cards as the MaX
    edition (fragments/fr/entites.frag.html, hubPage() of scripts/build-entities.mjs):
    entities cited by the documents present, how many are reconciled with Wikidata, size of
    the full register (counted in the source register), most cited entity.
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

    <xsl:template match="/">
        <xsl:variable name="all" select="$gs:perimeter/p"/>
        <!-- build report: perimeter per register, and the controls of the former import script
             as warnings (ids cited by the texts without register entry) -->
        <xsl:for-each select="$gs:types">
            <xsl:variable name="list" select="gs:entries(.)"/>
            <xsl:variable name="by_ref" select="$list[exists(key('gs:mentions', string(@xml:id), $gs:derived))]"/>
            <xsl:message select="concat(@source, ': ', count($list), ' entries published of ', count(gs:register-entries(.)),
                ' (', count($by_ref), ' referenced in the texts, ', count($list) - count($by_ref), ' only via note[@type=''sources''])')"/>
        </xsl:for-each>
        <xsl:variable name="orphans" select="$gs:derived/mentions/entity[not(key('gs:perimeter', @id, $gs:perimeter))]/@id"/>
        <xsl:message select="concat('registers: ', count($all), ' entries published for ', count($gs:doc-ids), ' documents')"/>
        <xsl:if test="exists($orphans)">
            <xsl:message select="concat('WARNING ', count($orphans), ' ids referenced in the texts without register entry: ', string-join($orphans, ' '))"/>
        </xsl:if>
        <xsl:call-template name="gs:page">
            <xsl:with-param name="title" select="'Index des entités'"/>
            <xsl:with-param name="body_class" select="'gs-hub-page'"/>
            <xsl:with-param name="content">
                <section class="gs-hub" aria-labelledby="gs-hub-title">
                    <p class="gs-section-marker">Référentiels d’autorité</p>
                    <h1 class="gs-hub-title" id="gs-hub-title">Index des entités</h1>
                    <p class="gs-hub-intro">Personnes, lieux, organisations, œuvres et autres entités
                        identifiées dans le corpus par détection automatique (NER) puis réconciliées avec
                        Wikidata. Chaque notice renvoie aux documents qui la citent. Les registres marqués
                        <xsl:call-template name="gs:exp-badge"/> sont expérimentaux : leur extraction
                        automatique est encore en cours de validation.
                        Démo : <xsl:value-of select="count($all)"/> entités citées dans les <xsl:value-of select="gs:number-fr(count($gs:doc-ids), false())"/> documents présentés.</p>
                    <ul class="gs-hub-grid">
                        <xsl:for-each select="$gs:types">
                            <xsl:variable name="t" select="."/>
                            <xsl:variable name="list" as="element()*">
                                <xsl:perform-sort select="gs:entries($t)">
                                    <xsl:sort select="gs:sort-key(.)" lang="fr"/>
                                </xsl:perform-sort>
                            </xsl:variable>
                            <xsl:variable name="recon" select="count($list[tei:idno[@type = 'wikidata']])"/>
                            <xsl:variable name="max" select="max(for $e in $list return gs:demo-mentions($e))"/>
                            <xsl:variable name="top" select="$list[gs:demo-mentions(.) = $max][1]"/>
                            <li>
                                <a class="gs-hub-card gs-hub-card-{$t/@key}" href="{$t/@page}">
                                    <span class="gs-hub-type">
                                        <xsl:value-of select="($t/@hub, $t/@label)[1]"/>
                                        <xsl:if test="$t/@exp"><xsl:call-template name="gs:exp-badge"/></xsl:if>
                                    </span>
                                    <span class="gs-hub-total"><xsl:value-of select="count($list)"/></span>
                                    <span class="gs-hub-stats">
                                        <span class="gs-hub-recon"><xsl:value-of select="concat($recon, ' réconciliée', if ($recon gt 1) then 's' else '')"/></span>
                                        <span class="gs-hub-corpus"><xsl:value-of select="count(gs:register-entries($t))"/> dans le corpus complet</span>
                                        <xsl:if test="$max gt 0">
                                            <span class="gs-hub-top"><xsl:value-of select="concat(gs:label($top), ' · ', $max, ' mentions')"/></span>
                                        </xsl:if>
                                    </span>
                                    <span class="gs-hub-desc"><xsl:value-of select="$t/@desc"/></span>
                                </a>
                            </li>
                        </xsl:for-each>
                    </ul>
                </section>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
</xsl:stylesheet>
