<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="2.0"
    exclude-result-prefixes="xsl tei xs">
    
    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/tabulator_dl_buttons.xsl"/>
    <xsl:import href="./partials/tabulator_js.xsl"/>
    <xsl:import href="./partials/blockquote.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>


    <xsl:template match="/">
        <xsl:variable name="doc_title" select="'Table des matières'"/>
        <xsl:variable name="link" select="'toc.html'"/>
        <html class="h-100" lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="$doc_title"></xsl:with-param>
                </xsl:call-template>
                <xsl:call-template name="zoterMetaTags">
                    <xsl:with-param name="pageId" select="$link"></xsl:with-param>
                    <xsl:with-param name="zoteroTitle" select="$doc_title"></xsl:with-param>
                </xsl:call-template>
            </head>
            
            <body class="d-flex flex-column h-100">
            <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                    <nav style="--bs-breadcrumb-divider: '>';" aria-label="breadcrumb" class="ps-5 p-3">
                        <ol class="breadcrumb">
                            <li class="breadcrumb-item">
                                <a href="index.html">
                                    <xsl:value-of select="$project_short_title"/>
                                </a>
                            </li>
                            <li class="breadcrumb-item active" aria-current="page">
                                <xsl:value-of select="$doc_title"/>
                            </li>
                        </ol>
                    </nav>
                    <div class="container">
                        <h1><xsl:value-of select="$doc_title"/></h1>
                        <p>Cinq imprimés du XVII<sup>e</sup> siècle, transcrits et annotés par le projet Grand Siècle (UNIL). Chaque document est publié page par page, avec le fac-similé Gallica.</p>
                        <table id="myTable">
                            <thead>
                                <tr>
                                    <th scope="col" width="20" tabulator-formatter="html" tabulator-headerSort="false" tabulator-download="false">#</th>
                                    <th scope="col" tabulator-headerFilter="input">Titre</th>
                                    <th scope="col" tabulator-headerFilter="input">Auteur</th>
                                    <th scope="col" tabulator-headerFilter="input">Date</th>
                                    <th scope="col" tabulator-headerFilter="input">Langues</th>
                                    <th scope="col" tabulator-sorter="number">Pages</th>
                                    <th scope="col" tabulator-headerFilter="input">Fichier</th>
                                </tr>
                            </thead>
                            <tbody>
                                <xsl:for-each select="collection('../data/editions?select=*.xml')//tei:TEI">
                                    <xsl:sort select="tokenize(document-uri(/), '/')[last()]"/>
                                    <xsl:variable name="file" select="tokenize(document-uri(/), '/')[last()]"/>
                                    <tr>
                                        <td>
                                            <a href="{replace($file, '\.xml$', '.html')}">
                                                <i class="bi bi-link-45deg"/>
                                            </a>
                                        </td>
                                        <td>
                                            <a href="{replace($file, '\.xml$', '.html')}">
                                                <xsl:value-of select="normalize-space(tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1])"/>
                                            </a>
                                        </td>
                                        <td><xsl:call-template name="doc_author"><xsl:with-param name="tei" select="."/></xsl:call-template></td>
                                        <td><xsl:call-template name="doc_date"><xsl:with-param name="tei" select="."/></xsl:call-template></td>
                                        <td><xsl:call-template name="doc_languages"><xsl:with-param name="tei" select="."/></xsl:call-template></td>
                                        <td><xsl:call-template name="doc_page_count"><xsl:with-param name="tei" select="."/></xsl:call-template></td>
                                        <td><xsl:value-of select="$file"/></td>
                                    </tr>
                                </xsl:for-each>
                            </tbody>
                        </table>
                        <xsl:call-template name="tabulator_dl_buttons"/>
                        <div class="text-center p-4">
                            <xsl:call-template name="blockquote">
                                <xsl:with-param name="pageId" select="'toc.html'"/>
                            </xsl:call-template>
                        </div>
                    </div>
                </main>
                <xsl:call-template name="html_footer"/>
                <xsl:call-template name="tabulator_js"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>