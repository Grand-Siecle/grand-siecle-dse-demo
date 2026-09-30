<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: one edition = one document page ({ID}.html, principal output of the
    Ant <xslt> task) + one HTML page per printed page ({ID}-page-{n}.html, written with
    xsl:result-document). The TEI is read as the project encoded it (data/editions holds the
    source files unchanged):
    - pages are cut on tei:pb; n = rank of the pb in the text (the pb carry no @n);
    - the image of a page is found by resolving pb/@corresp to sourceDoc/surface/graphic/@url
      (IIIF, full size in the source; 1200 px high here, as in MaX);
    - tei:sourceDoc (ALTO-derived zones and lines, ~68 % of the file) and tei:standOff are
      not rendered: only text/body is.
    Departures from these assumptions are reported as build warnings (xsl:message), not errors.

    Both pages follow the MaX edition:
    - document page = MaX ui/xsl/tei/document_toc.xsl (metadata card + grid of page thumbnails);
    - reading page = MaX text_hook.xsl / nav_bar.xsl / grand-siecle.js: page navigation in the
      header bar (arrows + page selector), display toolbar (layer, forme work, word analysis,
      entity filter, legend), breadcrumb, page context, facsimile next to the text.
      Both layers (orig / reg) are in the HTML, the visible one is chosen by html/@data-layer
      (CSS) and switched by js/gs-reader.js; named entities are linked to the register pages
      (popover in js/gs-reader.js); marginal notes; forme work (fw); @lang on every page and
      passage; word annotations (lemma, POS, msd) as data-*.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    xmlns:gsdoc="urn:grand-siecle:doc"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="no" omit-xml-declaration="yes"/>

    <!-- document id taken from the file name (LIV0019_reconciled.tei.xml -> LIV0019, partials/doc_meta.xsl);
         TEI/@xml:id is left as in the source; the source file itself is offered for download -->
    <xsl:variable name="doc_id" select="gsdoc:id-from-uri(string(document-uri(/)))"/>
    <xsl:variable name="teiSource" select="tokenize(document-uri(/), '/')[last()]"/>
    <xsl:variable name="link" select="concat($doc_id, '.html')"/>
    <xsl:variable name="doc_title" select="normalize-space(/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1])"/>
    <xsl:variable name="page_count" select="count(/tei:TEI/tei:text//tei:pb)"/>
    <xsl:variable name="doc_author">
        <xsl:call-template name="doc_author"><xsl:with-param name="tei" select="/tei:TEI"/></xsl:call-template>
    </xsl:variable>
    <!-- main language = langUsage/language with the highest @usage -->
    <xsl:variable name="doc_lang" as="xs:string" select="gs:lang((gsdoc:langs(/tei:TEI), 'fra')[1])"/>
    <!-- default layer, as in MaX: original for the Latin text (LIV0010), modernised otherwise -->
    <xsl:variable name="default_layer" select="if ($doc_lang = 'la') then 'orig' else 'reg'"/>

    <!-- register entries (the nine source registers, complete) used to resolve entity @ref:
         an id cited by the text is in the published perimeter by definition -->
    <xsl:variable name="indices" select="collection('../data/indices?select=*.xml')"/>
    <xsl:key name="entry" match="*[matches(@xml:id, '^[a-z]+-[0-9]{6}$')]" use="@xml:id"/>

    <!-- facsimile of a page: pb/@corresp -> sourceDoc/surface/graphic/@url -->
    <xsl:key name="surface" match="tei:sourceDoc/tei:surface" use="@xml:id"/>
    <xsl:function name="gs:facs" as="xs:string">
        <xsl:param name="pb" as="element(tei:pb)"/>
        <xsl:variable name="url" select="string((key('surface', substring-after($pb/@corresp, '#'), root($pb))/tei:graphic/@url)[1])"/>
        <xsl:sequence select="replace($url, 'full/full/0/native', 'full/,1200/0/native')"/>
    </xsl:function>
    <!-- page number: rank of the pb (pb are children of body/div, checked below) -->
    <xsl:function name="gs:page-n" as="xs:integer">
        <xsl:param name="pb" as="element(tei:pb)"/>
        <xsl:sequence select="count($pb/preceding-sibling::tei:pb) + 1"/>
    </xsl:function>

    <xsl:variable name="entity_elements" select="/tei:TEI/tei:text//(tei:persName | tei:placeName | tei:orgName | tei:rs
        | tei:objectName | tei:material | tei:title | tei:date[@ref])"/>

    <!-- ISO 639-2/3 codes of the TEI -> BCP 47 for HTML @lang -->
    <xsl:function name="gs:lang" as="xs:string">
        <xsl:param name="code" as="xs:string?"/>
        <xsl:sequence select="if ($code = 'fra') then 'fr' else if ($code = 'lat') then 'la'
            else if ($code = 'ita') then 'it' else if ($code = 'grc') then 'grc'
            else if ($code) then $code else 'fr'"/>
    </xsl:function>

    <xsl:function name="gs:ref" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="substring-after(tokenize(normalize-space($e/@ref), ' ')[1], '#')"/>
    </xsl:function>

    <xsl:function name="gs:resolved" as="xs:boolean">
        <xsl:param name="ref" as="xs:string"/>
        <xsl:sequence select="$ref != '' and (some $d in $indices satisfies exists(key('entry', $ref, $d)))"/>
    </xsl:function>

    <!-- entity type from the @ref prefix first (an element may be misleading), then from the element -->
    <xsl:function name="gs:entity-type" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="prefix" select="substring-before(gs:ref($e), '-')"/>
        <xsl:sequence select="
            if ($prefix = ('person', 'place', 'org', 'work', 'event', 'artwork', 'material', 'technique', 'date')) then $prefix
            else if ($e/self::tei:persName) then 'person'
            else if ($e/self::tei:placeName) then 'place'
            else if ($e/self::tei:orgName) then 'org'
            else if ($e/self::tei:title) then 'work'
            else if ($e/self::tei:objectName) then 'artwork'
            else if ($e/self::tei:material) then 'material'
            else if ($e/self::tei:rs[@type]) then string($e/@type)
            else 'date'"/>
    </xsl:function>

    <!-- Gallica viewer page of an IIIF image URL: .../iiif/ark:/12148/bpt6k.../f44/full/... -> .../ark:/12148/bpt6k.../f44.item -->
    <xsl:function name="gs:gallica-page" as="xs:string">
        <xsl:param name="iiif" as="xs:string"/>
        <xsl:sequence select="replace($iiif, '^https://gallica\.bnf\.fr/iiif/(ark:/[^/]+/[^/]+/f[0-9]+)/.*$', 'https://gallica.bnf.fr/$1.item')"/>
    </xsl:function>

    <xsl:template match="/">
        <!-- assumptions of the pagination on the Grand Siecle encoding: warnings, not errors -->
        <xsl:variable name="div" select="/tei:TEI/tei:text/tei:body/tei:div"/>
        <xsl:if test="count($div) ne 1">
            <xsl:message select="concat('WARNING ', $doc_id, ': ', count($div), ' text/body/div (one expected); only the pages of the first are built')"/>
        </xsl:if>
        <xsl:variable name="stray_pb" select="count(/tei:TEI/tei:text//tei:pb) - count($div[1]/tei:pb)"/>
        <xsl:if test="$stray_pb gt 0">
            <xsl:message select="concat('WARNING ', $doc_id, ': ', $stray_pb, ' pb not children of body/div, ignored for the pagination')"/>
        </xsl:if>
        <xsl:if test="$div[1]/*[1][not(self::tei:pb)]">
            <xsl:message select="concat('WARNING ', $doc_id, ': body/div does not start with a pb; the content before the first pb is not shown')"/>
        </xsl:if>
        <xsl:variable name="unexpected" select="distinct-values($div[1]/*[not(self::tei:pb or self::tei:ab or self::tei:fw or self::tei:note)]/name())"/>
        <xsl:if test="exists($unexpected)">
            <xsl:message select="concat('WARNING ', $doc_id, ': body/div children not handled by the reading pages: ', string-join($unexpected, ', '))"/>
        </xsl:if>
        <xsl:variable name="no_image" select="$div[1]/tei:pb[gs:facs(.) = '']"/>
        <xsl:if test="$no_image">
            <xsl:message select="concat('WARNING ', $doc_id, ': ', count($no_image), ' page(s) without image (pb/@corresp not resolved to sourceDoc/surface/graphic/@url): p. ',
                string-join(for $pb in $no_image return string(gs:page-n($pb)), ', '))"/>
        </xsl:if>
        <xsl:variable name="unresolved" select="$entity_elements[not(gs:resolved(gs:ref(.)))]"/>
        <xsl:message select="concat($doc_id, ': ', count($entity_elements), ' entity elements, ',
            count($unresolved), ' without a register entry (rendered without link)', if ($unresolved) then concat(': ', string-join(distinct-values(for $u in $unresolved return (gs:ref($u)[. != ''], concat('(', name($u), ' without @ref)'))[1]), ' ')) else '')"/>
        <xsl:call-template name="document_page">
            <xsl:with-param name="unresolved" select="$unresolved"/>
        </xsl:call-template>

        <!-- one page per tei:pb (body/div children are pb|ab|fw|note, see the warnings above) -->
        <xsl:for-each-group select="/tei:TEI/tei:text/tei:body/tei:div[1]/*" group-starting-with="tei:pb">
            <xsl:if test="current-group()[1][self::tei:pb]">
            <xsl:call-template name="reading_page">
                <xsl:with-param name="pb" select="current-group()[1]"/>
                <xsl:with-param name="content" select="current-group()[position() gt 1]"/>
            </xsl:call-template>
            </xsl:if>
        </xsl:for-each-group>
    </xsl:template>

    <!-- ============================ document page (MaX document_toc.xsl) ============================ -->
    <xsl:template name="document_page">
        <xsl:param name="unresolved" as="element()*"/>
        <xsl:variable name="fileDesc" select="/tei:TEI/tei:teiHeader/tei:fileDesc"/>
        <xsl:variable name="author" select="$fileDesc/tei:titleStmt/tei:author[1]"/>
        <xsl:variable name="ms" select="$fileDesc/tei:sourceDesc/tei:msDesc/tei:msIdentifier"/>
        <xsl:variable name="manifest" select="string($ms/tei:idno[@type = 'iiif'][1])"/>
        <xsl:variable name="publishers" select="gsdoc:publishers(/tei:TEI, ())"/>
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
                <meta name="citation_author" content="{$doc_author}"/>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <h1 class="gs-doc-fiche-title"><xsl:value-of select="$doc_title"/></h1>
                    <div class="gs-doc-fiche">
                        <dl class="gs-doc-meta">
                            <xsl:if test="normalize-space($doc_author)">
                                <dt>Auteur</dt>
                                <dd>
                                    <xsl:value-of select="$doc_author"/>
                                    <xsl:variable name="birth" select="substring(string($author/tei:birth/@when), 1, 4)"/>
                                    <xsl:variable name="death" select="substring(string($author/tei:death/@when), 1, 4)"/>
                                    <xsl:if test="$birth != '' or $death != ''">
                                        <xsl:value-of select="concat(' (', $birth, '–', $death, ')')"/>
                                    </xsl:if>
                                </dd>
                            </xsl:if>
                            <dt>Publication</dt>
                            <dd>
                                <xsl:value-of select="normalize-space($fileDesc/tei:sourceDesc/tei:bibl/tei:pubPlace[1])"/>
                                <xsl:if test="exists($publishers)"><xsl:value-of select="concat(', chez ', string-join($publishers, ' · '))"/></xsl:if>
                                <xsl:value-of select="concat(', ', gsdoc:date(/tei:TEI))"/>
                            </dd>
                            <dt>Langues</dt>
                            <dd><xsl:value-of select="string-join(gsdoc:langs(/tei:TEI), ', ')"/></dd>
                            <xsl:if test="$ms/tei:idno[@type = 'ark']">
                                <dt>Source</dt>
                                <dd>
                                    <a href="https://gallica.bnf.fr/{$ms/tei:idno[@type = 'ark'][1]}"><xsl:value-of select="$ms/tei:idno[@type = 'ark'][1]"/></a>
                                    <xsl:text> (Gallica / BnF)</xsl:text>
                                </dd>
                            </xsl:if>
                            <xsl:if test="$manifest != ''">
                                <dt>IIIF</dt>
                                <dd>
                                    <a href="{$manifest}">manifeste</a>
                                    <xsl:text> · </xsl:text>
                                    <a href="{replace($manifest, '/iiif/(ark:/[^/]+/[^/]+)/manifest\.json$', '/$1')}">voir sur Gallica</a>
                                </dd>
                            </xsl:if>
                            <!-- DSE additions: the TEI file and the entity count -->
                            <dt>Source TEI</dt>
                            <dd><a href="{$teiSource}" download="{$teiSource}"><xsl:value-of select="$teiSource"/></a></dd>
                            <dt>Entités</dt>
                            <dd>
                                <xsl:value-of select="concat(count($entity_elements), ' mentions annotées')"/>
                                <xsl:if test="$unresolved">
                                    <xsl:value-of select="concat(' (dont ', count($unresolved), ' sans fiche de registre)')"/>
                                </xsl:if>
                            </dd>
                        </dl>
                    </div>
                    <xsl:variable name="pages" as="element(page)*">
                        <xsl:for-each-group select="/tei:TEI/tei:text/tei:body/tei:div[1]/*" group-starting-with="tei:pb">
                            <xsl:for-each select="current-group()[1][self::tei:pb]">
                                <page n="{gs:page-n(.)}" facs="{gs:facs(.)}" empty="{empty(current-group()/self::tei:ab)}"/>
                            </xsl:for-each>
                        </xsl:for-each-group>
                    </xsl:variable>
                    <h2 class="gs-section-title">Pages <span class="gs-doc-pagecount">(<xsl:value-of select="count($pages)"/>)</span></h2>
                    <xsl:if test="$pages[@empty = 'true']">
                        <p class="gs-doc-stats"><span aria-hidden="true">◦ </span>fac-similé seul (page non transcrite)</p>
                    </xsl:if>
                    <ul class="gs-page-grid">
                        <xsl:for-each select="$pages">
                            <li>
                                <a href="{$doc_id}-page-{@n}.html">
                                    <img class="gs-page-thumb" loading="lazy" decoding="async" width="300" height="440" alt=""
                                        src="{replace(@facs, '/full/[^/]+/', '/full/,300/')}"/>
                                    <span class="gs-page-label">
                                        <xsl:value-of select="concat('p. ', @n)"/>
                                        <xsl:if test="@empty = 'true'">
                                            <span class="gs-page-empty" title="page non transcrite"><span aria-hidden="true"> ◦</span><span class="visually-hidden"> (fac-similé seul)</span></span>
                                        </xsl:if>
                                    </span>
                                </a>
                            </li>
                        </xsl:for-each>
                    </ul>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
            </body>
        </html>
    </xsl:template>

    <!-- ========================= reading page (MaX text_hook / nav_bar) ========================= -->

    <!-- page navigation shown in the header bar; the selector lists the current page only,
         js/gs-reader.js fills in the other pages (saves ~17 kB on each of the 888 pages) -->
    <xsl:template name="page_nav">
        <xsl:param name="n" as="xs:integer"/>
        <nav class="gs-page-nav" aria-label="Navigation dans le document">
            <xsl:choose>
                <xsl:when test="$n gt 1">
                    <a class="gs-page-arrow gs-page-prev" href="{$doc_id}-page-{$n - 1}.html" rel="prev" title="Page précédente" aria-label="Page précédente">←</a>
                </xsl:when>
                <xsl:otherwise><span class="gs-page-arrow gs-page-off" aria-hidden="true">←</span></xsl:otherwise>
            </xsl:choose>
            <select class="gs-page-select" aria-label="Aller à la page" data-doc="{$doc_id}" data-max="{$page_count}">
                <option value="{$doc_id}-page-{$n}.html" selected="selected"><xsl:value-of select="concat('p. ', $n)"/></option>
            </select>
            <xsl:choose>
                <xsl:when test="$n lt $page_count">
                    <a class="gs-page-arrow gs-page-next" href="{$doc_id}-page-{$n + 1}.html" rel="next" title="Page suivante" aria-label="Page suivante">→</a>
                </xsl:when>
                <xsl:otherwise><span class="gs-page-arrow gs-page-off" aria-hidden="true">→</span></xsl:otherwise>
            </xsl:choose>
        </nav>
    </xsl:template>

    <!-- display toolbar (built by JavaScript in MaX, static here; hidden without JavaScript) -->
    <xsl:template name="toolbar">
        <div class="gs-doc-toolbar" role="group" aria-label="Options d’affichage du texte">
            <span class="gs-toolbar-group" role="group" aria-labelledby="gs-layer-label">
                <span class="gs-toolbar-label" id="gs-layer-label">Couche</span>
                <button type="button" class="gs-toolbar-btn gs-layer-btn" data-value="orig" aria-pressed="{$default_layer = 'orig'}">Original</button>
                <button type="button" class="gs-toolbar-btn gs-layer-btn" data-value="reg" aria-pressed="{$default_layer = 'reg'}">Modernisé</button>
            </span>
            <button type="button" class="gs-toolbar-btn gs-fw-btn" aria-pressed="false">Éléments de forme</button>
            <button type="button" class="gs-toolbar-btn gs-ling-btn" aria-pressed="false">Analyse linguistique</button>
            <span class="gs-ling-status" aria-live="polite"></span>
            <span class="gs-toolbar-group">
                <label class="gs-toolbar-label" for="gs-ner-select">Entités</label>
                <select class="gs-toolbar-select" id="gs-ner-select">
                    <option value="all">Toutes les entités</option>
                    <option value="high">Haute confiance</option>
                    <option value="off">Masquées</option>
                </select>
            </span>
            <!-- the legend (entity types and confidence lines) is added here by js/gs-reader.js -->
        </div>
    </xsl:template>

    <xsl:template name="reading_page">
        <xsl:param name="pb" as="element(tei:pb)"/>
        <xsl:param name="content" as="element()*"/>
        <xsl:variable name="n" select="gs:page-n($pb)"/>
        <xsl:variable name="facs" select="gs:facs($pb)"/>
        <!-- printed page number: LIV0010 surface ids "fN-M" (M = printed number), otherwise the first NumberingZone -->
        <xsl:variable name="printed" select="normalize-space((
            replace($pb/@corresp, '^#f[0-9]+-(.+)$', '$1')[not(. = ('np', $pb/@corresp))],
            string-join($content/self::tei:fw[@type = 'NumberingZone'][1]//text()[not(ancestor::tei:reg)], ''))[normalize-space()][1])"/>
        <xsl:variable name="page_lang" as="xs:string">
            <xsl:variable name="langs" as="xs:string*">
                <xsl:for-each-group select="$content/self::tei:ab" group-by="string(@xml:lang)">
                    <xsl:sort select="count(current-group())" order="descending"/>
                    <xsl:sequence select="current-grouping-key()"/>
                </xsl:for-each-group>
            </xsl:variable>
            <xsl:sequence select="if ($langs[1]) then gs:lang($langs[1]) else $doc_lang"/>
        </xsl:variable>
        <xsl:variable name="label" select="concat('Page ', $n, ' / ', $page_count)"/>
        <xsl:variable name="gallica" select="gs:gallica-page($facs)"/>
        <xsl:result-document href="{$doc_id}-page-{$n}.html">
            <html lang="{$default_lang}" data-layer="{$default_layer}" data-default-layer="{$default_layer}" data-doc="{$doc_id}">
                <head>
                    <xsl:call-template name="html_head">
                        <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $label)"/>
                        <xsl:with-param name="bootstrap_icons" select="false()"/>
                    </xsl:call-template>
                    <xsl:if test="$n gt 1"><link rel="prev" href="{$doc_id}-page-{$n - 1}.html"/></xsl:if>
                    <xsl:if test="$n lt $page_count"><link rel="next" href="{$doc_id}-page-{$n + 1}.html"/></xsl:if>
                    <script src="js/gs-reader.js" defer="defer"></script>
                </head>
                <body class="d-flex flex-column min-vh-100 gs-reader">
                    <xsl:call-template name="nav_bar">
                        <xsl:with-param name="page_nav" as="node()*">
                            <xsl:call-template name="page_nav"><xsl:with-param name="n" select="$n"/></xsl:call-template>
                        </xsl:with-param>
                    </xsl:call-template>
                    <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                        <xsl:call-template name="toolbar"/>
                        <nav class="gs-breadcrumb" aria-label="Fil d'Ariane">
                            <ol class="breadcrumb">
                                <li class="breadcrumb-item"><a href="toc.html">Corpus</a></li>
                                <li class="breadcrumb-item"><a href="{$link}"><xsl:value-of select="$doc_title"/></a></li>
                                <li class="breadcrumb-item active" aria-current="page"><xsl:value-of select="concat('p. ', $n)"/></li>
                            </ol>
                        </nav>
                        <div class="gs-doc-context">
                            <a class="gs-doc-back" href="{$link}"><span aria-hidden="true">← </span>Fiche du document</a>
                            <h1 class="gs-doc-title"><xsl:value-of select="$doc_title"/></h1>
                            <div class="gs-doc-pageinfo">
                                <span class="gs-doc-id"><xsl:value-of select="$doc_id"/></span>
                                <xsl:value-of select="concat(' · page ', $n, ' / ', $page_count)"/>
                                <xsl:if test="$printed != ''">
                                    <xsl:text> · </xsl:text>
                                    <span class="gs-printed" title="Numéro imprimé sur la page (lu par OCR)">p. imprimée <xsl:value-of select="$printed"/></span>
                                </xsl:if>
                                <xsl:text> · </xsl:text>
                                <a href="{$gallica}">voir sur Gallica</a>
                            </div>
                        </div>
                        <section class="page" id="{$doc_id}-page-{$n}" data-n="{$n}" aria-label="{$label}">
                            <figure class="page-facsimile">
                                <a href="{$gallica}" title="Ouvrir la page dans Gallica (BnF)">
                                    <img src="{replace($facs, ',1200', ',800')}" loading="lazy" decoding="async"
                                        alt="Fac-similé de la page {$n} ({if ($printed != '') then concat('p. imprimée ', $printed, ', ') else ''}vue Gallica) de « {$doc_title} »"/>
                                </a>
                                <figcaption class="page-facs-caption">p. <xsl:value-of select="$n"/> — Gallica (BnF)</figcaption>
                            </figure>
                            <div class="page-transcription" lang="{$page_lang}">
                                <xsl:choose>
                                    <xsl:when test="$content">
                                        <xsl:apply-templates select="$content"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <p class="page-untranscribed">Page sans texte transcrit (fac-similé seul).</p>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </div>
                        </section>
                    </main>
                    <xsl:call-template name="html_footer">
                        <xsl:with-param name="bootstrap_js" select="false()"/>
                    </xsl:call-template>
                </body>
            </html>
        </xsl:result-document>
    </xsl:template>

    <!-- ======================= text rendering ======================= -->
    <!-- partials/shared.xsl (template rules for generic TEI and Bootstrap entity modals) is no
         longer imported: every element of the page content is handled here, which keeps the
         reading pages independent of the register partials (entities.xsl). -->

    <xsl:template match="tei:date">
        <span class="date"><xsl:apply-templates/></span>
    </xsl:template>

    <xsl:template match="tei:ab">
        <div class="zone zone-{lower-case(@type)}">
            <xsl:if test="@xml:lang"><xsl:attribute name="lang" select="gs:lang(@xml:lang)"/></xsl:if>
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!-- serialisation whitespace between tokens/lines is dropped, spacing is rebuilt by tok-space;
         the reg layer (real mixed text) is not affected -->
    <xsl:template match="tei:*[tei:w or tei:s or tei:choice or tei:lb]/text()[not(normalize-space())]"/>

    <!-- line breaks, except the first one of a block -->
    <xsl:template match="tei:lb">
        <xsl:if test="preceding-sibling::node()[self::* or self::text()[normalize-space()]]"><br/></xsl:if>
    </xsl:template>

    <!-- both layers are output; CSS shows one according to html/@data-layer -->
    <xsl:template match="tei:choice">
        <span class="line-choice">
            <span class="layer layer-orig"><xsl:apply-templates select="tei:orig/node()"/></span>
            <span class="layer layer-reg"><xsl:apply-templates select="tei:reg/node()"/></span>
        </span>
    </xsl:template>

    <!-- lines without modernisation: shown in both layers -->
    <xsl:template match="tei:s[not(ancestor::tei:choice)]">
        <xsl:call-template name="tok-space"/>
        <span class="layer layer-both"><xsl:apply-templates/></span>
    </xsl:template>
    <!-- consecutive sentences on one line are separated by a space -->
    <xsl:template match="tei:s">
        <xsl:call-template name="tok-space"/>
        <xsl:apply-templates/>
    </xsl:template>

    <!-- space before a token (or a sentence), except: first item of its parent, after a line
         break, pc glued to the left, after a pc glued to the right, after an elided word (l’, qu’)
         - the last rule is not in MaX -->
    <xsl:template name="tok-space">
        <xsl:variable name="prev" select="preceding-sibling::*[1]"/>
        <xsl:if test="not(self::tei:pc[@join = 'left']) and $prev and not($prev[self::tei:lb])
            and not($prev[self::tei:pc][@join = 'right']) and not($prev[self::tei:w][matches(., '[’'']$')])">
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>

    <xsl:template match="tei:w">
        <xsl:call-template name="tok-space"/>
        <span class="w">
            <xsl:if test="@lemma"><xsl:attribute name="data-lemma" select="@lemma"/></xsl:if>
            <xsl:if test="@pos"><xsl:attribute name="data-pos" select="@pos"/></xsl:if>
            <xsl:if test="@msd and @msd != 'MORPH=empty'"><xsl:attribute name="data-msd" select="@msd"/></xsl:if>
            <xsl:if test="@next"><xsl:attribute name="data-next">1</xsl:attribute></xsl:if>
            <xsl:value-of select="."/>
        </span>
    </xsl:template>

    <xsl:template match="tei:pc">
        <xsl:call-template name="tok-space"/>
        <xsl:value-of select="."/>
    </xsl:template>

    <!-- named entities: link to the register page if the @ref resolves, plain span otherwise;
         type, register id and NER confidence as data-* for the popover (js/gs-reader.js), as in MaX -->
    <xsl:template match="tei:persName | tei:placeName | tei:orgName | tei:rs | tei:objectName | tei:material | tei:title | tei:date[@ref]">
        <xsl:variable name="ref" select="gs:ref(.)"/>
        <xsl:variable name="type" select="gs:entity-type(.)"/>
        <xsl:if test="parent::tei:s or parent::tei:foreign"><xsl:call-template name="tok-space"/></xsl:if>
        <xsl:choose>
            <xsl:when test="gs:resolved($ref)">
                <a class="ent ent-{$type}" href="{$ref}.html" data-type="{$type}" data-ref="{$ref}">
                    <xsl:if test="@cert"><xsl:attribute name="data-cert" select="@cert"/></xsl:if>
                    <xsl:apply-templates/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <span class="ent ent-{$type} ent-unresolved" data-type="{$type}">
                    <xsl:if test="$ref != ''"><xsl:attribute name="data-ref" select="$ref"/></xsl:if>
                    <xsl:if test="@cert"><xsl:attribute name="data-cert" select="@cert"/></xsl:if>
                    <xsl:apply-templates/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="tei:foreign">
        <xsl:if test="parent::tei:s"><xsl:call-template name="tok-space"/></xsl:if>
        <span class="foreign">
            <xsl:if test="@xml:lang"><xsl:attribute name="lang" select="gs:lang(@xml:lang)"/></xsl:if>
            <xsl:apply-templates/>
        </span>
    </xsl:template>

    <!-- forme work: printed page number always visible, running titles and quire marks behind a toggle -->
    <xsl:template match="tei:fw[@type = 'NumberingZone']">
        <span class="fw fw-numbering" title="Numéro de page imprimé">
            <xsl:if test="@xml:lang"><xsl:attribute name="lang" select="gs:lang(@xml:lang)"/></xsl:if>
            <xsl:apply-templates/>
        </span>
    </xsl:template>
    <xsl:template match="tei:fw">
        <div class="fw fw-{lower-case(replace(@type, 'Zone$', ''))}" hidden="hidden">
            <xsl:if test="@xml:lang"><xsl:attribute name="lang" select="gs:lang(@xml:lang)"/></xsl:if>
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!-- marginal notes -->
    <xsl:template match="tei:note">
        <aside class="marginal-note note-{lower-case(replace(@type, 'Zone$', ''))}" aria-label="Note marginale">
            <xsl:if test="@xml:lang"><xsl:attribute name="lang" select="gs:lang(@xml:lang)"/></xsl:if>
            <xsl:apply-templates/>
        </aside>
    </xsl:template>
</xsl:stylesheet>
