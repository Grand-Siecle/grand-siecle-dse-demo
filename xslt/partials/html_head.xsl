<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: <head> shared by every page. Same theme as the MaX edition
    (ui/css/grand-siecle.css, tokens -gs-*), self-hosted fonts in html/fonts/.
    Bootstrap CSS stays (MaX loads it too, and the register pages use its grid and tables);
    Bootstrap Icons are only loaded when a page asks for them (bootstrap_icons = true(),
    the default, so that pages which do not pass the parameter are unchanged).
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all"
    version="2.0">
    <xsl:include href="./params.xsl"/>
    <xsl:template name="html_head">
        <xsl:param name="html_title" select="$project_short_title"/>
        <xsl:param name="bootstrap_icons" as="xs:boolean" select="true()"/>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <link rel="icon" href="images/favicon.ico" sizes="any"/>
        <title><xsl:value-of select="$html_title"/></title>
        <meta name="description" content="{$project_description}"/>
        <meta property="og:type" content="website"/>
        <meta property="og:title" content="{$html_title}"/>
        <meta property="og:description" content="{$project_description}"/>
        <meta property="og:site_name" content="{$project_short_title}"/>
        <!-- the mobile menu is collapsed only when JavaScript runs (js/gs-nav.js opens it) -->
        <script>document.documentElement.classList.add('gs-js');</script>
        <link rel="stylesheet" href="vendor/bootstrap-5.3.5-dist/css/bootstrap.min.css"/>
        <xsl:if test="$bootstrap_icons">
            <link rel="stylesheet" href="vendor/bootstrap-icons/font/bootstrap-icons.min.css"/>
        </xsl:if>
        <link rel="stylesheet" href="css/style.css"/>
        <script src="js/gs-nav.js" defer="defer"></script>
    </xsl:template>
</xsl:stylesheet>
