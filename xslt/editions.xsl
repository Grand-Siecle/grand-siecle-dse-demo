<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: one edition = one landing page ({ID}.html, principal output of the
    Ant <xslt> task) + one HTML page per printed page ({ID}-page-{n}.html, written with
    xsl:result-document). Pages are cut on tei:pb, which the import script
    (pyscripts/import_data.py) numbers (@n, @xml:id) and links to their IIIF image (@facs).
    J1 renders the original layer (tei:orig) only; reg layer, entities, notes and image
    viewer are J2.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    version="2.0"
    exclude-result-prefixes="xsl tei xs">

    <xsl:import href="./partials/shared.xsl"/>
    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/blockquote.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <!-- document id taken from the file name (LIV0019.xml -> LIV0019); TEI/@xml:id is left as in the source -->
    <xsl:variable name="doc_id" select="replace(tokenize(document-uri(/), '/')[last()], '\.xml$', '')"/>
    <xsl:variable name="teiSource" select="concat($doc_id, '.xml')"/>
    <xsl:variable name="link" select="concat($doc_id, '.html')"/>
    <xsl:variable name="doc_title" select="normalize-space(/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1])"/>
    <xsl:variable name="page_count" select="count(/tei:TEI/tei:text//tei:pb)"/>
    <xsl:variable name="doc_author">
        <xsl:call-template name="doc_author"><xsl:with-param name="tei" select="/tei:TEI"/></xsl:call-template>
    </xsl:variable>

    <xsl:template name="breadcrumb">
        <xsl:param name="current"/>
        <nav style="--bs-breadcrumb-divider: '>';" aria-label="fil d'Ariane" class="ps-5 p-3">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="index.html"><xsl:value-of select="$project_short_title"/></a></li>
                <li class="breadcrumb-item"><a href="toc.html">Table des matières</a></li>
                <xsl:choose>
                    <xsl:when test="$current">
                        <li class="breadcrumb-item"><a href="{$link}"><xsl:value-of select="$doc_title"/></a></li>
                        <li class="breadcrumb-item active" aria-current="page"><xsl:value-of select="$current"/></li>
                    </xsl:when>
                    <xsl:otherwise>
                        <li class="breadcrumb-item active" aria-current="page"><xsl:value-of select="$doc_title"/></li>
                    </xsl:otherwise>
                </xsl:choose>
            </ol>
        </nav>
    </xsl:template>

    <xsl:template match="/">
        <!-- 1. landing page of the document -->
        <xsl:variable name="bibl" select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl"/>
        <xsl:variable name="ms" select="/tei:TEI/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:msDesc/tei:msIdentifier"/>
        <html class="h-100" lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="$doc_title"/>
                </xsl:call-template>
                <xsl:call-template name="zoterMetaTags">
                    <xsl:with-param name="pageId" select="$link"/>
                    <xsl:with-param name="zoteroTitle" select="$doc_title"/>
                </xsl:call-template>
                <meta name="citation_author" content="{$doc_author}"/>
            </head>
            <body class="d-flex flex-column h-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                    <xsl:call-template name="breadcrumb"/>
                    <div class="container">
                        <h1><xsl:value-of select="$doc_title"/></h1>
                        <dl class="row">
                            <dt class="col-sm-3">Auteur</dt>
                            <dd class="col-sm-9"><xsl:value-of select="$doc_author"/></dd>
                            <dt class="col-sm-3">Édition</dt>
                            <dd class="col-sm-9">
                                <xsl:value-of select="string-join((normalize-space($bibl/tei:pubPlace), normalize-space($bibl/tei:date))[. != ''], ', ')"/>
                                <xsl:for-each select="$bibl/tei:respStmt">
                                    <xsl:text> — </xsl:text>
                                    <xsl:value-of select="normalize-space(tei:resp)"/>
                                    <xsl:text> : </xsl:text>
                                    <xsl:value-of select="normalize-space(string-join((tei:persName/tei:forename, tei:persName/tei:surname), ' '))"/>
                                </xsl:for-each>
                            </dd>
                            <dt class="col-sm-3">Langues</dt>
                            <dd class="col-sm-9">
                                <xsl:call-template name="doc_languages"><xsl:with-param name="tei" select="/tei:TEI"/></xsl:call-template>
                            </dd>
                            <dt class="col-sm-3">Exemplaire</dt>
                            <dd class="col-sm-9">
                                <xsl:value-of select="string-join(($ms/tei:repository, $ms/tei:idno[not(@type)]), ' ')"/>
                                <xsl:if test="$ms/tei:idno[@type = 'ark']">
                                    <xsl:text> — </xsl:text>
                                    <a href="https://catalogue.bnf.fr/{$ms/tei:idno[@type = 'ark']}">notice BnF</a>
                                </xsl:if>
                                <xsl:if test="$ms/tei:idno[@type = 'iiif']">
                                    <xsl:text> — </xsl:text>
                                    <a href="{$ms/tei:idno[@type = 'iiif']}">manifeste IIIF (Gallica)</a>
                                </xsl:if>
                            </dd>
                            <dt class="col-sm-3">Pages</dt>
                            <dd class="col-sm-9"><xsl:value-of select="$page_count"/></dd>
                            <dt class="col-sm-3">Source TEI</dt>
                            <dd class="col-sm-9"><a href="{$teiSource}"><i class="bi bi-download"/><xsl:text> </xsl:text><xsl:value-of select="$teiSource"/></a></dd>
                        </dl>
                        <p>
                            <a class="btn btn-primary" href="{$doc_id}-page-1.html">Commencer la lecture</a>
                        </p>
                        <h2 class="fs-4">Pages</h2>
                        <ol class="list-inline page-index">
                            <xsl:for-each select="/tei:TEI/tei:text//tei:pb">
                                <li class="list-inline-item"><a href="{$doc_id}-page-{@n}.html"><xsl:value-of select="@n"/></a></li>
                            </xsl:for-each>
                        </ol>
                        <div class="text-center p-4">
                            <xsl:call-template name="blockquote">
                                <xsl:with-param name="pageId" select="$link"/>
                            </xsl:call-template>
                        </div>
                    </div>
                </main>
                <xsl:call-template name="html_footer"/>
            </body>
        </html>

        <!-- 2. one page per tei:pb (body/div children are pb|ab|fw|note, checked by the import script) -->
        <xsl:for-each-group select="/tei:TEI/tei:text/tei:body/tei:div/*" group-starting-with="tei:pb">
            <xsl:variable name="pb" select="current-group()[1]"/>
            <xsl:variable name="n" select="xs:integer($pb/@n)"/>
            <xsl:variable name="label" select="concat('Page ', $n, ' / ', $page_count)"/>
            <xsl:result-document href="{$doc_id}-page-{$n}.html">
                <html class="h-100" lang="{$default_lang}">
                    <head>
                        <xsl:call-template name="html_head">
                            <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $label)"/>
                        </xsl:call-template>
                    </head>
                    <body class="d-flex flex-column h-100">
                        <xsl:call-template name="nav_bar"/>
                        <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                            <xsl:call-template name="breadcrumb">
                                <xsl:with-param name="current" select="$label"/>
                            </xsl:call-template>
                            <div class="container">
                                <nav class="row align-items-center page-nav" aria-label="navigation entre les pages">
                                    <div class="col-3 text-start">
                                        <xsl:if test="$n gt 1">
                                            <a href="{$doc_id}-page-{$n - 1}.html" rel="prev"><i class="bi bi-chevron-left"/> Page précédente</a>
                                        </xsl:if>
                                    </div>
                                    <div class="col-6 text-center">
                                        <h1 class="fs-4"><a href="{$link}"><xsl:value-of select="$doc_title"/></a></h1>
                                        <p class="mb-0"><xsl:value-of select="$label"/>
                                            <xsl:text> · </xsl:text>
                                            <a href="{$pb/@facs}">fac-similé (Gallica)</a>
                                        </p>
                                    </div>
                                    <div class="col-3 text-end">
                                        <xsl:if test="$n lt $page_count">
                                            <a href="{$doc_id}-page-{$n + 1}.html" rel="next">Page suivante <i class="bi bi-chevron-right"/></a>
                                        </xsl:if>
                                    </div>
                                </nav>
                                <article class="page-text" id="{$pb/@xml:id}" data-facs="{$pb/@facs}">
                                    <xsl:choose>
                                        <xsl:when test="count(current-group()) gt 1">
                                            <xsl:apply-templates select="current-group()[position() gt 1]"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <p class="text-muted fst-italic">Page sans texte transcrit.</p>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </article>
                            </div>
                        </main>
                        <xsl:call-template name="html_footer"/>
                    </body>
                </html>
            </xsl:result-document>
        </xsl:for-each-group>
    </xsl:template>

    <!-- J1 minimal rendering of the original layer; overrides partials/shared.xsl -->
    <xsl:template match="tei:ab">
        <div class="ab {@type}"><xsl:apply-templates/></div>
    </xsl:template>
    <xsl:template match="tei:fw">
        <div class="fw {@type} text-muted small"><xsl:apply-templates/></div>
    </xsl:template>
    <xsl:template match="tei:note">
        <aside class="note {@type} small border-start ps-2"><xsl:apply-templates/></aside>
    </xsl:template>
    <xsl:template match="tei:choice">
        <xsl:apply-templates select="tei:orig"/>
    </xsl:template>
    <xsl:template match="tei:lb[not(preceding-sibling::*)]"/>
    <!-- no space before punctuation glued to the previous word -->
    <xsl:template match="text()[not(normalize-space())][following-sibling::*[1][self::tei:pc[@join = 'left']]]"/>
</xsl:stylesheet>
