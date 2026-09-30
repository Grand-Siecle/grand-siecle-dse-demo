<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): entity page ({xml:id}.html) and TEI export ({xml:id}.xml) of one
    register entry, same content and layout as the MaX entity pages (detailPage() of
    scripts/build-entities.mjs): label and reconciliation badge, dates or country, counters,
    description, attested forms, facts by type, authority links, provenance and export,
    co-occurrences, citing documents with passages in context (KWIC) linked to the pages.
    Called by xslt/listentity.xsl for every entry of an index file.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:gs="urn:grand-siecle"
    version="2.0" exclude-result-prefixes="#all">

    <xsl:import href="./registres.xsl"/>

    <!-- facts by type: sequence of <row key="…">value</row> (value may hold a link) -->
    <xsl:template name="gs:facts" as="element()*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="p" select="gs:prefix($e)"/>
        <xsl:choose>
            <xsl:when test="$p = 'person'">
                <row key="Naissance"><xsl:value-of select="gs:disp-year(gs:birth($e))"/></row>
                <row key="Décès"><xsl:value-of select="gs:disp-year(gs:death($e))"/></row>
                <row key="Occupations"><xsl:value-of select="string-join($e/tei:occupation[normalize-space()], ', ')"/></row>
                <row key="Nationalité"><xsl:value-of select="string-join($e/tei:nationality[normalize-space()], ', ')"/></row>
                <row key="Sexe"><xsl:value-of select="$e/tei:sex[1]"/></row>
            </xsl:when>
            <xsl:when test="$p = 'place'">
                <row key="Pays"><xsl:value-of select="$e/tei:country[1]"/></row>
                <xsl:variable name="geo" select="tokenize(normalize-space($e/tei:location[1]/tei:geo[1]), ' ')"/>
                <xsl:if test="count($geo) = 2 and (every $g in $geo satisfies $g castable as xs:double)">
                    <row key="Coordonnées">
                        <xsl:value-of select="concat($geo[1], ' ', $geo[2])"/>
                        <xsl:text> · </xsl:text>
                        <a href="carte.html#{$e/@xml:id}">voir sur la carte</a>
                        <xsl:text> · </xsl:text>
                        <a href="https://www.openstreetmap.org/?mlat={$geo[1]}&amp;mlon={$geo[2]}#map=6/{$geo[1]}/{$geo[2]}"
                            rel="external noopener" target="_blank" title="Ouvre openstreetmap.org dans un nouvel onglet">OpenStreetMap</a>
                    </row>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$p = 'work'">
                <xsl:variable name="author" select="$e/tei:author[1]"/>
                <xsl:variable name="person" select="if ($author/@key) then ($gs:indices/key('gs:person-by-wikidata', string($author/@key)))[1] else ()"/>
                <row key="Auteur">
                    <xsl:choose>
                        <xsl:when test="$person"><a href="{$person/@xml:id}.html"><xsl:value-of select="normalize-space($author)"/></a></xsl:when>
                        <xsl:otherwise><xsl:value-of select="normalize-space($author)"/></xsl:otherwise>
                    </xsl:choose>
                </row>
                <row key="Langue"><xsl:value-of select="$e/tei:textLang[1]"/></row>
                <row key="Publication"><xsl:value-of select="gs:disp-year(gs:pub-year($e))"/></row>
            </xsl:when>
            <xsl:when test="$p = 'event'">
                <xsl:variable name="when" select="gs:event-date($e, 'when')"/>
                <row key="Date">
                    <xsl:value-of select="if (exists($when)) then gs:disp-year($when)
                        else string-join((gs:disp-year(gs:event-date($e, 'notBefore')), gs:disp-year(gs:event-date($e, 'notAfter')))[. != ''], ' – ')"/>
                </row>
                <row key="Lieu"><xsl:value-of select="normalize-space(($e/tei:placeName[@key], $e/tei:placeName)[1])"/></row>
            </xsl:when>
            <xsl:when test="$p = 'artwork'">
                <row key="Type d’objet"><xsl:value-of select="$e/tei:objectType[1]"/></row>
            </xsl:when>
            <xsl:when test="$p = 'org'">
                <row key="Fondation"><xsl:value-of select="gs:disp-year(gs:foundation($e))"/></row>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="entity_page">
        <xsl:param name="e" as="element()" select="."/>
        <xsl:variable name="type" select="gs:type($e)"/>
        <xsl:variable name="id" select="string($e/@xml:id)"/>
        <xsl:variable name="label" select="gs:label($e)"/>
        <xsl:variable name="names" select="gs:names($e)"/>
        <xsl:variable name="conf" select="gs:confidence($e)"/>
        <xsl:variable name="demo" select="gs:demo-mentions($e)"/>
        <xsl:variable name="corpus" select="gs:corpus-mentions($e)"/>
        <xsl:variable name="cited" select="gs:cited-in($e)"/>
        <xsl:variable name="index" select="replace($type/@file, '\.xml$', '.html')"/>
        <xsl:variable name="forms" select="distinct-values(($names[@type = 'standard'][1], $names[@type = 'variant'])/normalize-space())[. != '' and . != $label]"/>
        <xsl:variable name="subhead" select="
            if (gs:prefix($e) = 'person' and exists((gs:birth($e), gs:death($e)))) then gs:year-range(gs:birth($e), gs:death($e), ' – ')
            else if (gs:prefix($e) = 'place') then normalize-space($e/tei:country[1]) else ''"/>
        <xsl:variable name="description" select="normalize-space(($e/tei:note[@type = 'description'], $e/tei:desc)[1])"/>
        <xsl:variable name="facts" as="element()*">
            <xsl:call-template name="gs:facts"><xsl:with-param name="e" select="$e"/></xsl:call-template>
        </xsl:variable>
        <xsl:variable name="idnos" select="$e/tei:idno[@type = $gs:auth/@type][normalize-space()]"/>
        <xsl:variable name="candidates" select="tokenize(normalize-space($e/tei:note[@type = 'wikidata-candidates'][1]), '\s*\|\s*')[. != '']"/>
        <xsl:variable name="cooccur" select="$e/tei:linkGrp[@type = 'cooccurrence']/tei:ptr"/>

        <xsl:call-template name="gs:page">
            <xsl:with-param name="title" select="$label"/>
            <xsl:with-param name="body_class" select="concat('gs-entity-page gs-entity-page-', $type/@key)"/>
            <xsl:with-param name="main_class" select="'gs-main gs-entity-main'"/>
            <xsl:with-param name="content">
                <article class="gs-entity-detail gs-entity-detail-{$type/@key}">
                    <p class="gs-entity-kicker">
                        <a class="gs-kicker-link" href="entites.html">Entités</a>
                        <xsl:text> · </xsl:text>
                        <a class="gs-kicker-link" href="{$index}"><xsl:value-of select="$type/@label"/></a>
                        <xsl:if test="$type/@exp"><xsl:text> </xsl:text><xsl:call-template name="gs:exp-badge"/></xsl:if>
                        <xsl:text> · </xsl:text>
                        <a class="gs-kicker-link" href="{$index}"><span aria-hidden="true">← </span><xsl:value-of select="$type/@back"/></a>
                    </p>
                    <header class="gs-authority-head">
                        <h1 class="gs-authority-title">
                            <span><xsl:value-of select="$label"/></span>
                            <xsl:text> </xsl:text>
                            <xsl:call-template name="gs:conf-badge"><xsl:with-param name="conf" select="$conf"/></xsl:call-template>
                        </h1>
                        <xsl:if test="$subhead != ''"><p class="gs-authority-sub"><xsl:value-of select="$subhead"/></p></xsl:if>
                        <p class="gs-authority-meta">
                            <span class="gs-entity-id"><xsl:value-of select="$id"/></span>
                            <xsl:if test="$demo gt 0">
                                <xsl:text> · </xsl:text>
                                <span class="gs-entity-mentions" title="mentions dans les documents de la démo"><xsl:value-of select="gs:plural($demo, 'mention')"/> (démo)</span>
                            </xsl:if>
                            <xsl:if test="$corpus gt 0">
                                <xsl:text> · </xsl:text>
                                <span title="mentions dans le corpus complet"><xsl:value-of select="$corpus"/> dans le corpus</span>
                            </xsl:if>
                        </p>
                    </header>
                    <xsl:if test="$description != ''"><p class="gs-authority-desc"><xsl:value-of select="$description"/></p></xsl:if>
                    <xsl:if test="exists($forms)">
                        <section class="gs-forms" aria-labelledby="forms-{$id}">
                            <h2 id="forms-{$id}">Formes attestées</h2>
                            <ul class="gs-variants">
                                <xsl:for-each select="$forms"><li class="gs-variant"><xsl:value-of select="."/></li></xsl:for-each>
                            </ul>
                        </section>
                    </xsl:if>
                    <xsl:if test="$facts[normalize-space()]">
                        <section class="gs-facts" aria-labelledby="facts-{$id}">
                            <h2 id="facts-{$id}">Informations</h2>
                            <dl class="gs-meta-rows">
                                <xsl:for-each select="$facts[normalize-space()]">
                                    <div class="gs-meta-row"><dt><xsl:value-of select="@key"/></dt><dd><xsl:copy-of select="node()"/></dd></div>
                                </xsl:for-each>
                            </dl>
                        </section>
                    </xsl:if>
                    <xsl:if test="$idnos">
                        <aside class="gs-authority-ids" aria-labelledby="ids-{$id}">
                            <h2 id="ids-{$id}">Référentiels</h2>
                            <ul>
                                <xsl:for-each select="$idnos">
                                    <xsl:variable name="auth" select="$gs:auth[@type = current()/@type]"/>
                                    <xsl:variable name="v" select="normalize-space(.)"/>
                                    <li>
                                        <a class="gs-auth-link" href="{$auth/@url}{replace(encode-for-uri($v), '%2F', '/')}" rel="external noopener" target="_blank"
                                            title="Ouvre {$auth/@host} dans un nouvel onglet">
                                            <span class="gs-auth-chip gs-auth-{@type}"><xsl:value-of select="$auth/@abbr"/></span>
                                            <xsl:text> </xsl:text>
                                            <span class="gs-auth-val"><xsl:value-of select="$v"/></span>
                                        </a>
                                        <xsl:if test="@type = 'wikidata' and @cert">
                                            <xsl:text> </xsl:text>
                                            <span class="gs-idno-cert">(<xsl:value-of select="gs:conf-fr(@cert)"/>)</span>
                                        </xsl:if>
                                    </li>
                                </xsl:for-each>
                            </ul>
                        </aside>
                    </xsl:if>
                    <section class="gs-provenance" aria-label="Provenance de la notice">
                        <p>Entité détectée automatiquement (NER CamemBERT + GLiNER), réconciliation Wikidata : <strong><xsl:value-of select="gs:conf-fr($conf)"/></strong>.</p>
                        <xsl:if test="$demo = 0 and $cited">
                            <p>Relevée dans le registre de
                                <xsl:for-each select="$cited">
                                    <xsl:if test="position() gt 1"> et de </xsl:if>
                                    <a href="{gs:doc-id(.)}.html"><xsl:value-of select="tei:title"/></a>
                                </xsl:for-each>, sans occurrence localisable dans la transcription.</p>
                        </xsl:if>
                        <xsl:if test="exists($candidates)">
                            <p class="gs-candidates">Candidats non retenus :
                                <xsl:for-each select="$candidates">
                                    <xsl:if test="position() gt 1"> · </xsl:if>
                                    <a href="https://www.wikidata.org/wiki/{.}" rel="external noopener" target="_blank"><xsl:value-of select="."/></a>
                                </xsl:for-each>
                            </p>
                        </xsl:if>
                        <p class="gs-export-actions">
                            <a class="gs-export-link" href="{$id}.xml" download="{$id}.xml"><span aria-hidden="true">↓ </span>Exporter TEI</a>
                            <xsl:text> </xsl:text>
                            <a class="gs-export-link" href="about.html">Signaler une erreur d’identification</a>
                        </p>
                    </section>
                    <xsl:if test="$cooccur">
                        <section class="gs-cooccur" aria-labelledby="cooccur-{$id}">
                            <h2 class="gs-cooccur-title" id="cooccur-{$id}">Cité dans les mêmes documents</h2>
                            <ul class="gs-cooccur-list">
                                <xsl:for-each select="$cooccur">
                                    <xsl:variable name="o" select="gs:entry(substring-after(@target, '#'))"/>
                                    <xsl:variable name="nd" select="xs:integer(@n)"/>
                                    <li>
                                        <a class="gs-cooccur-item gs-cooccur-{gs:type($o)/@key}" href="{$o/@xml:id}.html">
                                            <xsl:value-of select="gs:label($o)"/>
                                            <xsl:text> </xsl:text>
                                            <span class="gs-cooccur-meta"><xsl:value-of select="concat(gs:type($o)/@singular, ' · ', gs:plural($nd, 'doc'))"/></span>
                                        </a>
                                    </li>
                                </xsl:for-each>
                            </ul>
                        </section>
                    </xsl:if>
                    <section class="gs-backlinks" aria-labelledby="backlinks-{$id}">
                        <h2 class="gs-backlinks-title" id="backlinks-{$id}">
                            <xsl:text>Cité dans </xsl:text>
                            <span class="gs-backlinks-count"><xsl:value-of select="count($cited)"/></span>
                            <xsl:value-of select="if (count($cited) gt 1) then ' documents' else ' document'"/>
                            <xsl:if test="$demo gt 0">
                                <xsl:text> </xsl:text><span class="gs-backlinks-sep">·</span><xsl:text> </xsl:text>
                                <span class="gs-backlinks-mentions"><xsl:value-of select="$demo"/></span>
                                <xsl:value-of select="if ($demo gt 1) then ' mentions' else ' mention'"/>
                            </xsl:if>
                        </h2>
                        <ul class="gs-backlinks-list">
                            <xsl:for-each select="$cited">
                                <xsl:variable name="doc" select="gs:doc-id(.)"/>
                                <xsl:variable name="n" select="xs:integer((@n, 0)[1])"/>
                                <xsl:variable name="first" select="tei:ptr[@type = 'page']/@target"/>
                                <xsl:variable name="kwic" select="tei:cit[@type = 'kwic']"/>
                                <li class="gs-backlinks-item">
                                    <div class="gs-backlinks-row">
                                        <a class="gs-backlinks-doc" href="{$first}"><xsl:value-of select="tei:title"/></a>
                                        <xsl:text> </xsl:text>
                                        <a class="gs-backlinks-id" href="{$doc}.html" title="Fiche du document : {tei:title}"><xsl:value-of select="$doc"/></a>
                                        <xsl:if test="$n gt 0">
                                            <xsl:text> </xsl:text>
                                            <span class="gs-backlinks-n"><xsl:value-of select="gs:plural($n, 'mention')"/></span>
                                        </xsl:if>
                                    </div>
                                    <xsl:if test="$kwic">
                                        <details class="gs-kwic-details">
                                            <summary>
                                                <xsl:value-of select="if (@subtype = 'truncated') then concat('Extraits (', count($kwic), ' premiers)') else concat('Extraits (', count($kwic), ')')"/>
                                            </summary>
                                            <ul class="gs-kwic-panel">
                                                <xsl:for-each select="$kwic">
                                                    <li class="gs-kwic-line">
                                                        <a href="{tei:ptr/@target}">
                                                            <xsl:if test="tei:quote/@xml:lang"><xsl:attribute name="lang" select="tei:quote/@xml:lang"/></xsl:if>
                                                            <xsl:value-of select="tei:quote/tei:seg[@type = 'left']"/>
                                                            <xsl:text> </xsl:text>
                                                            <mark><xsl:value-of select="tei:quote/tei:seg[@type = 'kw']"/></mark>
                                                            <xsl:text> </xsl:text>
                                                            <xsl:value-of select="tei:quote/tei:seg[@type = 'right']"/>
                                                            <xsl:text> </xsl:text>
                                                            <span class="gs-kwic-page" lang="fr">p. <xsl:value-of select="@n"/></span>
                                                        </a>
                                                    </li>
                                                </xsl:for-each>
                                                <xsl:if test="@subtype = 'truncated'">
                                                    <li class="gs-kwic-line"><a href="{$first}">Toutes les occurrences dans le document <span aria-hidden="true">→</span></a></li>
                                                </xsl:if>
                                            </ul>
                                        </details>
                                    </xsl:if>
                                </li>
                            </xsl:for-each>
                        </ul>
                    </section>
                </article>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <!-- TEI export: the register entry as imported, without the data added for the pages -->
    <xsl:template name="entity_tei">
        <xsl:param name="e" as="element()" select="."/>
        <xsl:apply-templates select="$e" mode="gs:export"/>
    </xsl:template>
    <xsl:template match="tei:noteGrp[@type = 'mentions'] | tei:linkGrp[@type = 'cooccurrence']" mode="gs:export"/>
    <xsl:template match="@* | node()" mode="gs:export">
        <xsl:copy><xsl:apply-templates select="@* | node()" mode="gs:export"/></xsl:copy>
    </xsl:template>
</xsl:stylesheet>
