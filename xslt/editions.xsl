<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: one edition = one landing page ({ID}.html, principal output of the
    Ant <xslt> task) + one HTML page per printed page ({ID}-page-{n}.html, written with
    xsl:result-document). Pages are cut on tei:pb, which the import script
    (pyscripts/import_data.py) numbers (@n, @xml:id) and links to their IIIF image (@facs).

    Reading page (J2), modelled on the MaX edition (ui/xsl/tei/text_hook.xsl):
    both layers (orig / reg) are in the HTML, the visible one is chosen by
    html/@data-layer (CSS) and switched by js/gs-reader.js; facsimile next to the text;
    named entities linked to the register pages; marginal notes; forme work (fw);
    @lang on every page and passage; word annotations (lemma, POS, msd) as data-*.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/shared.xsl"/>
    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/blockquote.xsl"/>
    <xsl:import href="./partials/zotero.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="no" omit-xml-declaration="yes"/>

    <!-- document id taken from the file name (LIV0019.xml -> LIV0019); TEI/@xml:id is left as in the source -->
    <xsl:variable name="doc_id" select="replace(tokenize(document-uri(/), '/')[last()], '\.xml$', '')"/>
    <xsl:variable name="teiSource" select="concat($doc_id, '.xml')"/>
    <xsl:variable name="link" select="concat($doc_id, '.html')"/>
    <xsl:variable name="doc_title" select="normalize-space(/tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[1])"/>
    <xsl:variable name="page_count" select="count(/tei:TEI/tei:text//tei:pb)"/>
    <xsl:variable name="doc_author">
        <xsl:call-template name="doc_author"><xsl:with-param name="tei" select="/tei:TEI"/></xsl:call-template>
    </xsl:variable>
    <!-- main language = langUsage/language with the highest @usage -->
    <xsl:variable name="doc_lang" as="xs:string">
        <xsl:variable name="langs" as="xs:string*">
            <xsl:for-each select="/tei:TEI/tei:teiHeader/tei:profileDesc/tei:langUsage/tei:language">
                <xsl:sort select="xs:integer((@usage, 0)[1])" order="descending"/>
                <xsl:sequence select="string(@ident)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:sequence select="gs:lang(($langs, 'fra')[1])"/>
    </xsl:variable>
    <!-- default layer, as in MaX: original for the Latin text (LIV0010), modernised otherwise -->
    <xsl:variable name="default_layer" select="if ($doc_lang = 'la') then 'orig' else 'reg'"/>

    <!-- register entries (all data/indices files) used to resolve entity @ref -->
    <xsl:variable name="indices" select="collection('../data/indices?select=list*.xml')"/>
    <xsl:key name="entry" match="*[@xml:id]" use="@xml:id"/>

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

    <xsl:function name="gs:type-label" as="xs:string">
        <xsl:param name="type" as="xs:string"/>
        <xsl:sequence select="(('Personne', 'Lieu', 'Organisation', 'Œuvre', 'Événement', 'Objet', 'Matériau', 'Technique', 'Date')
            [index-of(('person', 'place', 'org', 'work', 'event', 'artwork', 'material', 'technique', 'date'), $type)[1]], $type)[1]"/>
    </xsl:function>

    <!-- Gallica viewer page of an IIIF image URL: .../iiif/ark:/12148/bpt6k.../f44/full/... -> .../ark:/12148/bpt6k.../f44.item -->
    <xsl:function name="gs:gallica-page" as="xs:string">
        <xsl:param name="iiif" as="xs:string"/>
        <xsl:sequence select="replace($iiif, '^https://gallica\.bnf\.fr/iiif/(ark:/[^/]+/[^/]+/f[0-9]+)/.*$', 'https://gallica.bnf.fr/$1.item')"/>
    </xsl:function>

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
        <!-- pagination invariants (also checked by the import script) -->
        <xsl:if test="count(/tei:TEI/tei:text//tei:pb) ne count(/tei:TEI/tei:text/tei:body/tei:div/tei:pb)
            or not(/tei:TEI/tei:text/tei:body/tei:div/*[1][self::tei:pb[@n][@facs]])">
            <xsl:message terminate="yes" select="concat($doc_id, ': every tei:pb must be a numbered child of body/div, and come first (run pyscripts/import_data.py)')"/>
        </xsl:if>
        <xsl:variable name="unresolved" select="$entity_elements[not(gs:resolved(gs:ref(.)))]"/>
        <xsl:message select="concat($doc_id, ': ', count($entity_elements), ' entity elements, ',
            count($unresolved), ' without a register entry (rendered without link)')"/>

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
                            <dt class="col-sm-3">Entités annotées</dt>
                            <dd class="col-sm-9">
                                <xsl:value-of select="count($entity_elements)"/>
                                <xsl:if test="$unresolved">
                                    <xsl:value-of select="concat(' (dont ', count($unresolved), ' sans fiche de registre)')"/>
                                </xsl:if>
                            </dd>
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
            <xsl:call-template name="reading_page">
                <xsl:with-param name="pb" select="current-group()[1]"/>
                <xsl:with-param name="content" select="current-group()[position() gt 1]"/>
            </xsl:call-template>
        </xsl:for-each-group>
    </xsl:template>

    <xsl:template name="page_nav">
        <xsl:param name="n" as="xs:integer"/>
        <xsl:param name="where" as="xs:string"/>
        <nav class="gs-page-nav gs-page-nav-{$where}" aria-label="Pages du document ({$where})">
            <xsl:choose>
                <xsl:when test="$n gt 1">
                    <a class="btn btn-outline-secondary gs-page-prev" href="{$doc_id}-page-{$n - 1}.html" rel="prev">
                        <span aria-hidden="true">← </span>Page précédente</a>
                </xsl:when>
                <xsl:otherwise><span class="btn btn-outline-secondary disabled" aria-disabled="true"><span aria-hidden="true">← </span>Page précédente</span></xsl:otherwise>
            </xsl:choose>
            <xsl:if test="$where = 'haut'">
                <form class="gs-jump" action="{$link}" data-doc="{$doc_id}" data-max="{$page_count}">
                    <label for="gs-jump-input">Aller à la page</label>
                    <input id="gs-jump-input" name="page" type="number" min="1" max="{$page_count}" value="{$n}" inputmode="numeric" class="form-control form-control-sm"/>
                    <span class="gs-jump-of">/ <xsl:value-of select="$page_count"/></span>
                    <button type="submit" class="btn btn-sm btn-outline-secondary">OK</button>
                </form>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="$n lt $page_count">
                    <a class="btn btn-outline-secondary gs-page-next" href="{$doc_id}-page-{$n + 1}.html" rel="next">Page suivante<span aria-hidden="true"> →</span></a>
                </xsl:when>
                <xsl:otherwise><span class="btn btn-outline-secondary disabled" aria-disabled="true">Page suivante<span aria-hidden="true"> →</span></span></xsl:otherwise>
            </xsl:choose>
        </nav>
    </xsl:template>

    <xsl:template name="reading_page">
        <xsl:param name="pb" as="element(tei:pb)"/>
        <xsl:param name="content" as="element()*"/>
        <xsl:variable name="n" select="xs:integer($pb/@n)"/>
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
        <xsl:variable name="gallica" select="gs:gallica-page($pb/@facs)"/>
        <xsl:result-document href="{$doc_id}-page-{$n}.html">
            <html class="h-100" lang="{$default_lang}" data-layer="{$default_layer}" data-default-layer="{$default_layer}" data-doc="{$doc_id}">
                <head>
                    <xsl:call-template name="html_head">
                        <xsl:with-param name="html_title" select="concat($doc_title, ' — ', $label)"/>
                    </xsl:call-template>
                    <xsl:if test="$n gt 1"><link rel="prev" href="{$doc_id}-page-{$n - 1}.html"/></xsl:if>
                    <xsl:if test="$n lt $page_count"><link rel="next" href="{$doc_id}-page-{$n + 1}.html"/></xsl:if>
                    <script src="js/gs-reader.js" defer="defer"/>
                </head>
                <body class="d-flex flex-column h-100 gs-reader">
                    <xsl:call-template name="nav_bar"/>
                    <main id="main" tabindex="-1" class="flex-shrink-0 flex-grow-1">
                        <xsl:call-template name="breadcrumb">
                            <xsl:with-param name="current" select="$label"/>
                        </xsl:call-template>
                        <div class="container-xxl gs-reader-container">
                            <header class="gs-reader-head">
                                <p class="gs-back"><a href="{$link}"><span aria-hidden="true">← </span>Fiche du document</a></p>
                                <h1><xsl:value-of select="$doc_title"/></h1>
                                <p class="gs-reader-meta">
                                    <span class="gs-doc-id"><xsl:value-of select="$doc_id"/></span>
                                    <xsl:value-of select="concat(' · page ', $n, ' / ', $page_count)"/>
                                    <xsl:if test="$printed != ''">
                                        <xsl:text> · </xsl:text>
                                        <span class="gs-printed" title="Numéro imprimé sur la page (lu par OCR)">p. imprimée <xsl:value-of select="$printed"/></span>
                                    </xsl:if>
                                    <xsl:text> · </xsl:text>
                                    <a href="{$gallica}">voir sur Gallica</a>
                                </p>
                            </header>
                            <div class="gs-toolbar">
                                <div class="gs-toolbar-group" role="group" aria-labelledby="gs-layer-label">
                                    <span class="gs-toolbar-label" id="gs-layer-label">Couche</span>
                                    <button type="button" class="btn btn-sm gs-layer-btn" data-value="orig" aria-pressed="{if ($default_layer = 'orig') then 'true' else 'false'}">Original</button>
                                    <button type="button" class="btn btn-sm gs-layer-btn" data-value="reg" aria-pressed="{if ($default_layer = 'reg') then 'true' else 'false'}">Modernisé</button>
                                </div>
                                <button type="button" class="btn btn-sm gs-fw-btn" aria-pressed="false">Éléments de forme</button>
                                <button type="button" class="btn btn-sm gs-ling-btn" aria-pressed="false">Analyse linguistique</button>
                                <span class="gs-ling-status" aria-live="polite"/>
                            </div>
                            <xsl:call-template name="page_nav">
                                <xsl:with-param name="n" select="$n"/>
                                <xsl:with-param name="where" select="'haut'"/>
                            </xsl:call-template>
                            <section class="gs-page" id="{$pb/@xml:id}" data-n="{$n}" aria-label="{$label}">
                                <figure class="page-facsimile">
                                    <a href="{$gallica}" title="Ouvrir la page dans Gallica (BnF)">
                                        <img src="{replace($pb/@facs, ',1200', ',800')}" loading="lazy" decoding="async"
                                            alt="Fac-similé de la page {$n} ({if ($printed != '') then concat('p. imprimée ', $printed, ', ') else ''}vue Gallica) de « {$doc_title} »"/>
                                    </a>
                                    <figcaption>Vue <xsl:value-of select="$n"/> — Gallica (BnF) · <a href="{$pb/@facs}">image IIIF</a></figcaption>
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
                            <xsl:call-template name="page_nav">
                                <xsl:with-param name="n" select="$n"/>
                                <xsl:with-param name="where" select="'bas'"/>
                            </xsl:call-template>
                            <p class="gs-kbd-hint">Raccourcis : touches <kbd>←</kbd> et <kbd>→</kbd> pour changer de page.</p>
                        </div>
                    </main>
                    <xsl:call-template name="html_footer"/>
                </body>
            </html>
        </xsl:result-document>
    </xsl:template>

    <!-- ======================= text rendering (overrides partials/shared.xsl) ======================= -->

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

    <!-- named entities: link to the register page if the @ref resolves, plain span otherwise -->
    <xsl:template match="tei:persName | tei:placeName | tei:orgName | tei:rs | tei:objectName | tei:material | tei:title | tei:date[@ref]">
        <xsl:variable name="ref" select="gs:ref(.)"/>
        <xsl:variable name="type" select="gs:entity-type(.)"/>
        <xsl:variable name="cert" select="if (@cert = 'high') then 'haute' else if (@cert = 'mid') then 'moyenne' else if (@cert = 'low') then 'faible' else ()"/>
        <xsl:variable name="title" select="string-join((gs:type-label($type), for $c in $cert return concat('confiance ', $c)), ' · ')"/>
        <xsl:if test="parent::tei:s or parent::tei:foreign"><xsl:call-template name="tok-space"/></xsl:if>
        <xsl:choose>
            <xsl:when test="gs:resolved($ref)">
                <a class="ent ent-{$type}" href="{$ref}.html" data-ref="{$ref}" title="{$title}">
                    <xsl:if test="@cert"><xsl:attribute name="data-cert" select="@cert"/></xsl:if>
                    <xsl:apply-templates/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <span class="ent ent-{$type} ent-unresolved" title="{$title} · sans fiche de registre">
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
