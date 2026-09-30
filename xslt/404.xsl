<?xml version="1.0" encoding="UTF-8"?>
<!-- Grand Siecle: "page not found" page (MaX has none; same layout as the editorial pages). -->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <html lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="concat('Page introuvable — ', $project_short_title)"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <div class="gs-page-editorial">
                        <p class="gs-section-kicker">Erreur 404</p>
                        <h1 class="gs-section-title">Page introuvable</h1>
                        <p class="gs-section-intro">L'adresse demandée ne correspond à aucune page de l'édition :
                            le lien est peut-être erroné, ou la page a changé de nom.</p>
                        <div class="gs-404-links">
                            <a class="gs-btn gs-btn-primary" href="index.html">Retour à l'accueil</a>
                            <a class="gs-btn gs-btn-ghost" href="toc.html">Parcourir le corpus</a>
                            <a class="gs-btn gs-btn-ghost" href="search.html">Rechercher</a>
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
