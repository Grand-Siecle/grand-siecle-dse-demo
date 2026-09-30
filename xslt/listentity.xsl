<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: generic register page for the five registers that have no counterpart in the
    template (events, artworks, materials, techniques, dates). Same layout as listorg.xsl:
    a Tabulator list ({file}.html) + one page per entry ({xml:id}.html, xsl:result-document).
    Entries are any element whose @xml:id looks like "{type}-000123".
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/tabulator_dl_buttons.xsl"/>
    <xsl:import href="./partials/tabulator_js.xsl"/>
    <xsl:import href="./partials/entities.xsl"/>
    <xsl:import href="./partials/blockquote.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:variable name="link" select="replace(tokenize(document-uri(/), '/')[last()], '\.xml$', '.html')"/>
    <xsl:variable name="doc_title" select="normalize-space(//tei:titleStmt/tei:title[1])"/>
    <xsl:variable name="entries" select="//*[matches(@xml:id, '^[a-z]+-[0-9]{6}$')]"/>

    <!-- names of an entry: typed children (label, objectName, date) or catDesc/term -->
    <xsl:function name="gs:names" as="element()*">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="($e/tei:catDesc/tei:term, $e/*[@type = ('main', 'standard', 'variant')], $e/tei:date[not(@type)][normalize-space()])"/>
    </xsl:function>
    <xsl:function name="gs:label" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="n" select="gs:names($e)"/>
        <xsl:sequence select="normalize-space(($n[@type = 'main'], $n[not(@type)], $n)[1])"/>
    </xsl:function>

    <xsl:template name="generic_detail">
        <dl>
            <xsl:call-template name="names"><xsl:with-param name="names" select="gs:names(.)"/></xsl:call-template>
            <xsl:if test="tei:date[@when or @notBefore or @notAfter]">
                <dt>Dates</dt>
                <dd><xsl:value-of select="string-join(tei:date/(@when, @notBefore, @notAfter), ' – ')"/></dd>
            </xsl:if>
            <xsl:if test="tei:placeName">
                <dt>Lieu</dt>
                <dd><xsl:value-of select="tei:placeName[1]"/></dd>
            </xsl:if>
            <xsl:if test="tei:desc">
                <dt>Description (Wikidata)</dt>
                <dd><xsl:value-of select="tei:desc[1]"/></dd>
            </xsl:if>
            <xsl:call-template name="description"/>
            <xsl:call-template name="idnos"/>
            <xsl:call-template name="mentions"/>
        </dl>
    </xsl:template>

    <xsl:template match="/">
        <html class="h-100" lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="$doc_title"/>
                </xsl:call-template>
                <xsl:call-template name="zoterMetaTags">
                    <xsl:with-param name="pageId" select="$link"/>
                    <xsl:with-param name="zoteroTitle" select="$doc_title"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column h-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                    <nav style="--bs-breadcrumb-divider: '>';" aria-label="fil d'Ariane" class="ps-5 p-3">
                        <ol class="breadcrumb">
                            <li class="breadcrumb-item"><a href="index.html"><xsl:value-of select="$project_short_title"/></a></li>
                            <li class="breadcrumb-item active" aria-current="page"><xsl:value-of select="$doc_title"/></li>
                        </ol>
                    </nav>
                    <div class="container">
                        <h1><xsl:value-of select="$doc_title"/></h1>
                        <p class="text-muted">Registre sans équivalent dans le gabarit DSE, rendu par une feuille générique.</p>
                        <table id="myTable">
                            <thead>
                                <tr>
                                    <th scope="col" width="20" tabulator-formatter="html" tabulator-headerSort="false" tabulator-download="false">#</th>
                                    <th scope="col" tabulator-headerFilter="input">Nom</th>
                                    <th scope="col" tabulator-headerFilter="input">Forme normalisée</th>
                                    <th scope="col" tabulator-headerFilter="input">ID</th>
                                </tr>
                            </thead>
                            <tbody>
                                <xsl:for-each select="$entries">
                                    <tr>
                                        <td><a href="{@xml:id}.html"><i class="bi bi-link-45deg"/></a></td>
                                        <td><xsl:value-of select="gs:label(.)"/></td>
                                        <td><xsl:value-of select="gs:names(.)[@type = 'standard'][1]"/></td>
                                        <td><xsl:value-of select="@xml:id"/></td>
                                    </tr>
                                </xsl:for-each>
                            </tbody>
                        </table>
                        <xsl:call-template name="tabulator_dl_buttons"/>
                    </div>
                </main>
                <xsl:call-template name="html_footer"/>
                <xsl:call-template name="tabulator_js"/>
            </body>
        </html>
        <xsl:for-each select="$entries">
            <xsl:variable name="filename" select="concat(@xml:id, '.html')"/>
            <xsl:variable name="name" select="gs:label(.)"/>
            <xsl:result-document href="{$filename}">
                <html class="h-100" lang="{$default_lang}">
                    <head>
                        <xsl:call-template name="html_head">
                            <xsl:with-param name="html_title" select="$name"/>
                        </xsl:call-template>
                    </head>
                    <body class="d-flex flex-column h-100">
                        <xsl:call-template name="nav_bar"/>
                        <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                            <nav style="--bs-breadcrumb-divider: '>';" aria-label="fil d'Ariane" class="ps-5 p-3">
                                <ol class="breadcrumb">
                                    <li class="breadcrumb-item"><a href="index.html"><xsl:value-of select="$project_short_title"/></a></li>
                                    <li class="breadcrumb-item"><a href="{$link}"><xsl:value-of select="$doc_title"/></a></li>
                                </ol>
                            </nav>
                            <div class="container">
                                <h1><xsl:value-of select="$name"/></h1>
                                <xsl:call-template name="generic_detail"/>
                            </div>
                        </main>
                        <xsl:call-template name="html_footer"/>
                    </body>
                </html>
            </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
