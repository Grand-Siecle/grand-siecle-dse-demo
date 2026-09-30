<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): one register index file -> its A-Z index page ({file}.html, e.g.
    listperson.html), one page per entry ({xml:id}.html) and one TEI export per entry
    ({xml:id}.xml). Same layout as the MaX index pages (ui/xsl/index/index_*.xsl): letters,
    one line per entity with dates / country / author, corpus count, citing documents.
    The template's Tabulator table is replaced by this list; js/gs-registres.js adds the
    instant filter and the facets (read from the data-* attributes written here).
    Used for the 9 index files (listperson/listplace/listorg/listbibl.xsl only import it).
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/entity_page.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="no" omit-xml-declaration="yes"/>
    <xsl:output name="tei" method="xml" encoding="UTF-8" indent="no"/>

    <xsl:variable name="entries" select="//*[matches(@xml:id, '^[a-z]+-[0-9]{6}$')]"/>
    <xsl:variable name="type" select="gs:type($entries[1])"/>

    <!-- facets of the index filter, by type: data attribute, label, values -->
    <xsl:function name="gs:facets" as="element()*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="p" select="gs:prefix($e)"/>
        <xsl:if test="$p = 'person'">
            <facet name="occupation" label="Occupation" values="{string-join($e/tei:occupation/normalize-space(), '|')}"/>
            <facet name="nationality" label="Nationalité" values="{string-join($e/tei:nationality/normalize-space(), '|')}"/>
            <facet name="sex" label="Sexe" values="{normalize-space($e/tei:sex[1])}"/>
        </xsl:if>
        <xsl:if test="$p = 'place'"><facet name="country" label="Pays" values="{normalize-space($e/tei:country[1])}"/></xsl:if>
        <xsl:if test="$p = 'work'"><facet name="lang" label="Langue" values="{normalize-space($e/tei:textLang[1])}"/></xsl:if>
        <xsl:if test="$p = 'event'"><facet name="place" label="Lieu" values="{normalize-space(($e/tei:placeName[@key], $e/tei:placeName)[1])}"/></xsl:if>
        <xsl:if test="$p = 'artwork'"><facet name="objtype" label="Type d’objet" values="{normalize-space($e/tei:objectType[1])}"/></xsl:if>
    </xsl:function>

    <!-- line complement: life dates (persons), country (places), author (works) -->
    <xsl:function name="gs:index-extra" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="p" select="gs:prefix($e)"/>
        <xsl:choose>
            <xsl:when test="$p = 'person'">
                <xsl:variable name="b" select="gs:disp-year(gs:birth($e))"/>
                <xsl:variable name="d" select="gs:disp-year(gs:death($e))"/>
                <xsl:sequence select="if ($b = '' and $d = '') then ''
                    else if (ends-with($b, ' av. J.-C.') and ends-with($d, ' av. J.-C.')) then concat(substring-before($b, ' av. J.-C.'), '–', $d)
                    else concat($b, '–', $d)"/>
            </xsl:when>
            <xsl:when test="$p = 'place'"><xsl:sequence select="normalize-space($e/tei:country[1])"/></xsl:when>
            <xsl:when test="$p = 'work'"><xsl:sequence select="normalize-space($e/tei:author[1])"/></xsl:when>
            <xsl:otherwise><xsl:sequence select="''"/></xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- A-Z letter: first letter of the sort key, accents removed, '#' otherwise -->
    <xsl:function name="gs:initial" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="k" select="translate(upper-case(substring(gs:sort-key($e), 1, 1)), 'ÀÂÄÉÈÊËÎÏÔÖÙÛÜÇŒ', 'AAAEEEEIIOOUUUCO')"/>
        <xsl:sequence select="if (matches($k, '^[A-Z]$')) then $k else '#'"/>
    </xsl:function>

    <!-- persons: the index shows the sort form (inverted, normalised) when it differs -->
    <xsl:function name="gs:index-label" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="s" select="gs:sort-name($e)"/>
        <xsl:sequence select="if (gs:prefix($e) = 'person' and $s != '' and $s != gs:label($e)) then $s else gs:label($e)"/>
    </xsl:function>

    <xsl:template match="/">
        <xsl:variable name="sorted" as="element()*">
            <xsl:perform-sort select="$entries">
                <xsl:sort select="gs:sort-key(.)" lang="fr"/>
            </xsl:perform-sort>
        </xsl:variable>
        <xsl:variable name="facet_names" select="distinct-values(gs:facets($entries[1])/@name)"/>
        <xsl:call-template name="gs:page">
            <xsl:with-param name="title" select="string($type/@label)"/>
            <xsl:with-param name="body_class" select="'gs-index-body'"/>
            <xsl:with-param name="content">
                <div class="gs-index-page">
                    <p class="gs-section-kicker">Index</p>
                    <h1 class="gs-section-title"><xsl:value-of select="$type/@label"/></h1>
                    <p class="gs-index-count"><strong><xsl:value-of select="count($entries)"/></strong> entités citées dans les
                        5 documents de la démonstration.</p>
                    <nav class="gs-az" aria-label="Accès alphabétique">
                        <xsl:for-each-group select="$sorted" group-by="gs:initial(.)">
                            <xsl:sort select="current-grouping-key()"/>
                            <a href="#az-{current-grouping-key()}"><xsl:value-of select="current-grouping-key()"/></a>
                        </xsl:for-each-group>
                    </nav>
                    <p class="gs-index-legend">Pastille dorée : mentions dans l’ensemble du corpus Grand Siècle · codes LIV : documents de la présente démonstration.</p>
                    <div id="index-{$type/@slug}" class="gs-index-list" data-type="{$type/@key}">
                        <xsl:for-each select="$facet_names">
                            <xsl:attribute name="data-facet-{.}" select="gs:facets($entries[1])[@name = current()]/@label"/>
                        </xsl:for-each>
                        <xsl:for-each-group select="$sorted" group-by="gs:initial(.)">
                            <xsl:sort select="current-grouping-key()"/>
                            <section class="gs-az-group" id="az-{current-grouping-key()}" aria-labelledby="az-h-{current-grouping-key()}">
                                <h2 class="gs-az-letter" id="az-h-{current-grouping-key()}"><xsl:value-of select="current-grouping-key()"/></h2>
                                <ul class="gs-index-ul">
                                    <xsl:for-each select="current-group()">
                                        <xsl:variable name="e" select="."/>
                                        <xsl:variable name="extra" select="gs:index-extra($e)"/>
                                        <li class="gs-index-item" data-conf="{gs:confidence($e)}"
                                            data-names="{string-join(distinct-values((gs:label($e), gs:names($e)/normalize-space())), '|')}">
                                            <xsl:for-each select="gs:facets($e)">
                                                <xsl:attribute name="data-f-{@name}" select="@values"/>
                                            </xsl:for-each>
                                            <a class="gs-index-link ent ent-{$type/@ent}" href="{@xml:id}.html"><xsl:value-of select="gs:index-label($e)"/></a>
                                            <xsl:if test="$extra != ''"><span class="gs-index-extra"><xsl:value-of select="$extra"/></span></xsl:if>
                                            <span class="gs-index-mentions" title="mentions dans le corpus complet"><xsl:value-of select="gs:corpus-mentions($e)"/></span>
                                            <span class="gs-index-docs">
                                                <xsl:for-each select="gs:cited-in($e)">
                                                    <a class="gs-doc-chip" href="{gs:doc-id(.)}.html" title="{tei:title}"><xsl:value-of select="gs:doc-id(.)"/></a>
                                                </xsl:for-each>
                                            </span>
                                        </li>
                                    </xsl:for-each>
                                </ul>
                            </section>
                        </xsl:for-each-group>
                    </div>
                </div>
            </xsl:with-param>
            <xsl:with-param name="scripts">
                <script src="js/gs-registres.js"/>
            </xsl:with-param>
        </xsl:call-template>

        <xsl:for-each select="$entries">
            <xsl:result-document href="{@xml:id}.html">
                <xsl:call-template name="entity_page"/>
            </xsl:result-document>
            <xsl:result-document href="{@xml:id}.xml" format="tei">
                <xsl:call-template name="entity_tei"/>
            </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
