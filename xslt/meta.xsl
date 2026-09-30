<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: editorial pages written in TEI (data/meta/*.xml, e.g. about.xml -> about.html),
    same layout as the MaX "À propos" fragment (fragments/fr/about.frag.html):
    kicker (titleStmt/title[@type='sub']), h1 with the gold rule, drop cap on the first
    paragraph, one h2 per tei:div/tei:head.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <xsl:variable name="doc_title" select="normalize-space(.//tei:titleStmt/tei:title[@type = 'main'][1])"/>
        <xsl:variable name="kicker" select="normalize-space(.//tei:titleStmt/tei:title[@type = 'sub'][1])"/>
        <xsl:variable name="link" select="replace(tokenize(document-uri(/), '/')[last()], '\.xml$', '.html')"/>
        <html lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $project_short_title)"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
                <xsl:call-template name="zoterMetaTags">
                    <xsl:with-param name="pageId" select="$link"/>
                    <xsl:with-param name="zoteroTitle" select="$doc_title"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <div class="gs-page-editorial">
                        <xsl:if test="$kicker != ''">
                            <p class="gs-section-kicker"><xsl:value-of select="$kicker"/></p>
                        </xsl:if>
                        <h1 class="gs-section-title"><xsl:value-of select="$doc_title"/></h1>
                        <xsl:apply-templates select=".//tei:body/node()"/>
                    </div>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="tei:div">
        <section><xsl:apply-templates/></section>
    </xsl:template>
    <xsl:template match="tei:div/tei:head">
        <h2><xsl:apply-templates/></h2>
    </xsl:template>
    <xsl:template match="tei:p">
        <p>
            <!-- drop cap on the first paragraph of the page, as in MaX -->
            <xsl:if test=". is (ancestor::tei:body//tei:p)[1]"><xsl:attribute name="class" select="'gs-lettrine'"/></xsl:if>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="tei:list">
        <xsl:element name="{if (@rend = 'numbered') then 'ol' else 'ul'}"><xsl:apply-templates select="tei:item"/></xsl:element>
    </xsl:template>
    <xsl:template match="tei:item"><li><xsl:apply-templates/></li></xsl:template>
    <xsl:template match="tei:hi[@rend = 'bold']"><strong><xsl:apply-templates/></strong></xsl:template>
    <xsl:template match="tei:hi[@rend = 'italic'] | tei:title"><em><xsl:apply-templates/></em></xsl:template>
    <xsl:template match="tei:hi[@rend = 'sup']"><sup><xsl:apply-templates/></sup></xsl:template>
    <xsl:template match="tei:code"><code><xsl:apply-templates/></code></xsl:template>
    <xsl:template match="tei:ref"><a href="{@target}"><xsl:apply-templates/></a></xsl:template>
    <xsl:template match="tei:lb"><br/></xsl:template>
</xsl:stylesheet>
