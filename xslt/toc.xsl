<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: Corpus page (toc.html), same as the MaX "sommaire" (ui/xsl/core/toc.xsl +
    xq/toc.xq): one card per edition, ordered by imprint date, computed from the teiHeader.
    MaX has no sort or filter on this page, so the template's Tabulator table is gone.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gsdoc="urn:grand-siecle:doc"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <xsl:variable name="doc_title" select="'Le corpus'"/>
        <html lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $project_short_title)"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
                <xsl:call-template name="zoterMetaTags">
                    <xsl:with-param name="pageId" select="'toc.html'"/>
                    <xsl:with-param name="zoteroTitle" select="$doc_title"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <div class="gs-sommaire">
                        <p class="gs-section-kicker">Corpus</p>
                        <h1 class="gs-section-title"><xsl:value-of select="$doc_title"/></h1>
                        <p class="gs-section-intro"><xsl:value-of select="gs:count-fr(count(gsdoc:editions()), 'imprimé', true())"/> du XVII<sup>e</sup> siècle, classés par date
                            d'édition, transcrits depuis les numérisations Gallica (ALTO), enrichis d'une couche
                            modernisée et d'entités nommées réconciliées avec Wikidata.</p>
                        <div class="gs-doc-grid">
                            <xsl:for-each select="gsdoc:editions()">
                                <xsl:call-template name="doc_card">
                                    <xsl:with-param name="tei" select="."/>
                                    <!-- no h2 on this page: card titles are the next level under h1 -->
                                    <xsl:with-param name="heading" select="'h2'"/>
                                </xsl:call-template>
                            </xsl:for-each>
                        </div>
                    </div>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
