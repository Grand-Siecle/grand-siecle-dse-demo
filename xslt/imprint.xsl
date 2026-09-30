<?xml version="1.0" encoding="UTF-8"?>
<!-- Grand Siecle: legal notice (data/imprint.xml, local file), same layout as the About page. -->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <xsl:variable name="doc_title" select="'Mentions légales'"/>
        <html lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $project_short_title)"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <div class="gs-page-editorial">
                        <p class="gs-section-kicker">Le projet</p>
                        <h1 class="gs-section-title"><xsl:value-of select="$doc_title"/></h1>
                        <xsl:copy-of select="/root/div/node()"/>
                    </div>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
