<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle (J4): shared pieces of the register pages (hub, A-Z indexes, entity pages,
    map, timeline), ported from the MaX edition (scripts/build-entities.mjs, ui/xsl/index/*).
    Data, all read as they are:
      - the nine source registers in data/indices (persons.xml, places.xml... complete,
        11 474 entries for the whole Grand Siecle corpus);
      - build/derived/mentions.xml, derived from the TEI editions at build time by
        pyscripts/derive_mentions.py (documents present, mentions, first page, passages).
    Computed here, at build time: the perimeter (entries cited by the documents present, or
    listing one of them in note[@type='sources']), the mention counts, the co-occurrences and
    the size of each full register. Nothing is written back into the TEI.
    Header, navigation and footer come from the common partials (html_head, nav_bar,
    html_footer); these pages add css/registres.css (and css/visualisations.css) themselves.
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./html_navbar.xsl"/>
    <xsl:import href="./html_head.xsl"/>
    <xsl:import href="./html_footer.xsl"/>

    <!-- the nine source registers (complete) and the data derived from the editions -->
    <xsl:variable name="gs:indices" select="collection('../../data/indices?select=*.xml')"/>
    <xsl:variable name="gs:derived" select="doc('../../build/derived/mentions.xml')"/>
    <xsl:variable name="gs:doc-ids" select="$gs:derived/mentions/doc/@id/string()"/>
    <xsl:key name="gs:entry" match="*[@xml:id]" use="@xml:id"/>
    <xsl:key name="gs:mentions" match="entity" use="@id"/>
    <xsl:key name="gs:perimeter" match="p" use="@id"/>
    <xsl:key name="gs:person-by-wikidata" match="tei:person" use="tei:idno[@type = 'wikidata']"/>

    <!-- register types: id prefix, class suffix, index file, labels (as in the MaX edition) -->
    <xsl:variable name="gs:types" as="element()*">
        <type prefix="person" key="person" ent="person" source="persons.xml" tag="person" name="persName" page="listperson.html" slug="personnes"
            label="Personnes" singular="Personne" back="Toutes les personnes"
            desc="Auteurs, peintres, imprimeurs, figures antiques…"/>
        <type prefix="place" key="place" ent="place" source="places.xml" tag="place" name="placeName" page="listplace.html" slug="lieux"
            label="Lieux" singular="Lieu" back="Tous les lieux"
            desc="Villes, régions et lieux cités, en partie géolocalisés."/>
        <type prefix="org" key="organization" ent="org" source="organizations.xml" tag="org" name="orgName" page="listorg.html" slug="organisations"
            label="Organisations" singular="Organisation" back="Toutes les organisations"
            desc="Académies, institutions, communautés."/>
        <type prefix="work" key="work" ent="work" source="works.xml" tag="bibl" name="title" page="listbibl.html" slug="oeuvres"
            label="Œuvres" singular="Œuvre" back="Toutes les œuvres"
            desc="Œuvres textuelles citées dans le corpus."/>
        <type prefix="event" key="event" ent="event" source="events.xml" tag="event" name="label" page="listevent.html" slug="evenements"
            label="Événements" singular="Événement" back="Tous les événements"
            desc="Événements historiques mentionnés."/>
        <type prefix="artwork" key="artwork" ent="artwork" source="artworks.xml" tag="object" name="objectName" page="listartwork.html" slug="objets" exp="true"
            label="Objets &amp; œuvres d'art" singular="Objet" back="Tous les objets"
            desc="Objets matériels et œuvres d'art — registre expérimental."/>
        <type prefix="material" key="material" ent="material" source="materials.xml" tag="category" name="term" page="listmaterial.html" slug="materiaux"
            label="Matériaux" singular="Matériau" back="Tous les matériaux"
            desc="Matériaux de la peinture et des arts."/>
        <type prefix="technique" key="technique" ent="technique" source="techniques.xml" tag="category" name="term" page="listtechnique.html" slug="techniques"
            label="Techniques" singular="Technique" back="Toutes les techniques"
            desc="Techniques et procédés artistiques."/>
        <type prefix="date" key="date" ent="date" source="dates.xml" tag="item" name="date" page="listdate.html" slug="dates" exp="true"
            label="Dates citées" hub="Dates" singular="Date" back="Toutes les dates"
            desc="Mentions de dates — registre expérimental."/>
    </xsl:variable>

    <!-- external authorities (rview:auth-url of the MaX edition) -->
    <xsl:variable name="gs:auth" as="element()*">
        <auth type="wikidata" abbr="Wikidata" host="wikidata.org" url="https://www.wikidata.org/wiki/"/>
        <auth type="viaf" abbr="VIAF" host="viaf.org" url="https://viaf.org/viaf/"/>
        <auth type="isni" abbr="ISNI" host="isni.org" url="https://isni.org/isni/"/>
        <auth type="gnd" abbr="GND" host="d-nb.info" url="https://d-nb.info/gnd/"/>
        <auth type="bnf" abbr="BnF" host="catalogue.bnf.fr" url="https://catalogue.bnf.fr/ark:/12148/cb"/>
        <auth type="lccn" abbr="LCCN" host="id.loc.gov" url="https://id.loc.gov/authorities/names/"/>
        <auth type="geonames" abbr="GeoNames" host="geonames.org" url="https://www.geonames.org/"/>
        <auth type="aat" abbr="Getty AAT" host="vocab.getty.edu" url="http://vocab.getty.edu/aat/"/>
    </xsl:variable>

    <xsl:variable name="gs:exp-title" select="'Registre expérimental : extraction automatique en cours de validation'"/>

    <!-- ============================ entries ============================ -->

    <xsl:function name="gs:prefix" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="substring-before($e/@xml:id, '-')"/>
    </xsl:function>

    <xsl:function name="gs:type" as="element()">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="$gs:types[@prefix = gs:prefix($e)]"/>
    </xsl:function>

    <xsl:function name="gs:entry" as="element()?">
        <xsl:param name="id" as="xs:string"/>
        <xsl:sequence select="($gs:indices/key('gs:entry', $id))[1]"/>
    </xsl:function>

    <!-- name elements of an entry (main, sort, standard, variant) -->
    <xsl:function name="gs:names" as="element()*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="p" select="gs:prefix($e)"/>
        <xsl:sequence select="
            if ($p = 'person') then $e/tei:persName
            else if ($p = 'place') then $e/tei:placeName
            else if ($p = 'org') then $e/tei:orgName
            else if ($p = 'work') then $e/tei:title
            else if ($p = 'event') then $e/tei:label
            else if ($p = 'artwork') then $e/tei:objectName
            else if ($p = ('material', 'technique')) then $e/tei:catDesc/tei:term
            else $e/tei:date"/>
    </xsl:function>

    <xsl:function name="gs:label" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="n" select="gs:names($e)"/>
        <xsl:sequence select="normalize-space(($n[@type = 'main'], $n[not(@type)][gs:prefix($e) = 'date'], $n)[1])"/>
    </xsl:function>

    <xsl:function name="gs:sort-name" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="normalize-space(gs:names($e)[@type = 'sort'][1])"/>
    </xsl:function>

    <xsl:function name="gs:sort-key" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="s" select="gs:sort-name($e)"/>
        <xsl:sequence select="lower-case(if ($s != '') then $s else gs:label($e))"/>
    </xsl:function>

    <xsl:function name="gs:confidence" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="c" select="normalize-space($e/tei:note[@type = 'reconciliation-confidence'][1])"/>
        <xsl:sequence select="if ($c = ('high', 'medium', 'low')) then $c else 'none'"/>
    </xsl:function>

    <xsl:function name="gs:conf-fr" as="xs:string">
        <xsl:param name="c" as="xs:string?"/>
        <xsl:sequence select="if ($c = 'high') then 'confiance forte' else if ($c = 'medium') then 'confiance moyenne'
            else if ($c = 'low') then 'confiance faible' else if ($c = ('none', '')) then 'non réconciliée' else $c"/>
    </xsl:function>

    <!-- ============================ perimeter ============================ -->

    <!-- all entries of a register (source file), whatever the documents present: element named
         as the type table says (person, bibl, category...) with an id "{prefix}-000000" -->
    <xsl:key name="gs:register-entry" match="tei:*[matches(@xml:id, '^[a-z]+-[0-9]{6}$')]"
        use="concat(local-name(), ' ', substring-before(@xml:id, '-'))"/>
    <xsl:function name="gs:register-entries" as="element()*">
        <xsl:param name="t" as="element(type)"/>
        <xsl:sequence select="key('gs:register-entry', concat($t/@tag, ' ', $t/@prefix),
            $gs:indices[ends-with(document-uri(.), concat('/', $t/@source))])"/>
    </xsl:function>

    <!-- documents present that cite an entry: @ref in the text (derived file) or
         note[@type='sources'] of the register (same rule as the MaX edition) -->
    <xsl:function name="gs:docs-of" as="xs:string*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="refs" select="key('gs:mentions', string($e/@xml:id), $gs:derived)/in/@doc/string()"/>
        <xsl:variable name="sources" select="for $s in tokenize(string($e/tei:note[@type = 'sources'][1]), '\|') return normalize-space($s)"/>
        <xsl:perform-sort select="$gs:doc-ids[. = ($refs, $sources)]">
            <xsl:sort select="." collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        </xsl:perform-sort>
    </xsl:function>

    <!-- label used to break ties between co-occurrences: name of type sort, else main, else first -->
    <xsl:function name="gs:tie-label" as="xs:string">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="names" select="$e//tei:*[local-name() = gs:type($e)/@name]"/>
        <xsl:sequence select="(normalize-space($names[@type = 'sort'][1]), normalize-space($names[@type = 'main'][1]),
            normalize-space($names[1]), '')[. != ''][1]"/>
    </xsl:function>

    <!-- one line per entry of the perimeter, in register order (persons, places...), with its
         documents, corpus count and tie-break keys; computed once per transformation -->
    <xsl:variable name="gs:perimeter" as="document-node()">
        <xsl:document>
            <xsl:for-each select="$gs:types">
                <xsl:for-each select="gs:register-entries(.)">
                    <xsl:variable name="docs" select="gs:docs-of(.)"/>
                    <xsl:if test="exists($docs)">
                        <xsl:variable name="label" select="gs:tie-label(.)"/>
                        <p id="{@xml:id}" docs="{$docs}" n="{(@n[. castable as xs:integer], 0)[1]}"
                            k1="{replace(normalize-unicode(lower-case($label), 'NFD'), '\p{M}', '')}" k2="{$label}"/>
                    </xsl:if>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:document>
    </xsl:variable>

    <xsl:function name="gs:in-perimeter" as="xs:boolean">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="exists(key('gs:perimeter', string($e/@xml:id), $gs:perimeter))"/>
    </xsl:function>

    <!-- entries of the perimeter (of one type, or all), in register order -->
    <xsl:function name="gs:entries" as="element()*">
        <xsl:param name="t" as="element(type)*"/>
        <xsl:sequence select="for $type in $t return gs:register-entries($type)[gs:in-perimeter(.)]"/>
    </xsl:function>

    <xsl:function name="gs:docs" as="xs:string*">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="tokenize(key('gs:perimeter', string($e/@xml:id), $gs:perimeter)/@docs, ' ')"/>
    </xsl:function>

    <!-- ============================ mentions ============================ -->

    <!-- one element per citing document: doc, title, n (mentions), first (page), truncated,
         and the passages (kwic) of the derived file -->
    <xsl:function name="gs:cited-in" as="element(cited)*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="m" select="key('gs:mentions', string($e/@xml:id), $gs:derived)"/>
        <xsl:for-each select="gs:docs($e)">
            <xsl:variable name="d" select="."/>
            <xsl:variable name="in" select="$m/in[@doc = $d]"/>
            <cited doc="{$d}" title="{$gs:derived/mentions/doc[@id = $d]/@title}" n="{($in/@n, 0)[1]}" first="{($in/@first, 1)[1]}">
                <xsl:copy-of select="$in/@truncated, $in/kwic"/>
            </cited>
        </xsl:for-each>
    </xsl:function>

    <!-- mentions in the documents present, corpus count (register @n) -->
    <xsl:function name="gs:demo-mentions" as="xs:integer">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="docs" select="gs:docs($e)"/>
        <xsl:sequence select="xs:integer(sum(key('gs:mentions', string($e/@xml:id), $gs:derived)/in[@doc = $docs]/@n))"/>
    </xsl:function>
    <xsl:function name="gs:corpus-mentions" as="xs:integer">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="xs:integer(($e/@n[. castable as xs:integer], 0)[1])"/>
    </xsl:function>

    <!-- entities of the perimeter sharing documents with $e: corpus count above 1, sorted by
         shared documents, corpus count, label (code points), 14 max (as build-entities.mjs) -->
    <xsl:function name="gs:cooccurrences" as="element(co)*">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="docs" select="gs:docs($e)"/>
        <xsl:variable name="candidates" as="element(co)*">
            <xsl:for-each select="$gs:perimeter/p[@id != $e/@xml:id][xs:integer(@n) gt 1]">
                <xsl:variable name="shared" select="tokenize(@docs, ' ')[. = $docs]"/>
                <xsl:if test="exists($shared)">
                    <!-- first shared document: order in which build-entities.mjs meets the entity -->
                    <co id="{@id}" nd="{count($shared)}" n="{@n}" k1="{@k1}" k2="{@k2}" first="{index-of($docs, $shared[1])}" pos="{position()}"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="sorted" as="element(co)*">
            <xsl:perform-sort select="$candidates">
                <xsl:sort select="xs:integer(@nd)" order="descending"/>
                <xsl:sort select="xs:integer(@n)" order="descending"/>
                <xsl:sort select="@k1" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                <xsl:sort select="@k2" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                <xsl:sort select="xs:integer(@first)"/>
                <xsl:sort select="xs:integer(@pos)"/>
            </xsl:perform-sort>
        </xsl:variable>
        <xsl:sequence select="$sorted[position() le 14]"/>
    </xsl:function>

    <xsl:function name="gs:plural" as="xs:string">
        <xsl:param name="n" as="xs:integer"/>
        <xsl:param name="word" as="xs:string"/>
        <xsl:sequence select="concat($n, ' ', $word, if ($n gt 1) then 's' else '')"/>
    </xsl:function>

    <!-- ============================ years ============================ -->

    <!-- integer year of an ISO date, possibly negative ("0354-11-13", "-0043") -->
    <xsl:function name="gs:year" as="xs:integer?">
        <xsl:param name="v" as="xs:string?"/>
        <xsl:variable name="s" select="normalize-space($v)"/>
        <xsl:sequence select="if (matches($s, '^-?\d')) then xs:integer(replace($s, '^(-?)0*(\d{1,4}).*$', '$1$2')) else ()"/>
    </xsl:function>

    <xsl:function name="gs:disp-year" as="xs:string">
        <xsl:param name="y" as="xs:integer?"/>
        <xsl:sequence select="if (empty($y)) then '' else if ($y lt 0) then concat(-$y, ' av. J.-C.') else string($y)"/>
    </xsl:function>

    <!-- one "av. J.-C." when both ends are BC; "?" for a missing end -->
    <xsl:function name="gs:year-range" as="xs:string">
        <xsl:param name="a" as="xs:integer?"/>
        <xsl:param name="b" as="xs:integer?"/>
        <xsl:param name="sep" as="xs:string"/>
        <xsl:sequence select="if (exists($a) and exists($b) and $a lt 0 and $b lt 0) then concat(-$a, $sep, -$b, ' av. J.-C.')
            else concat(if (exists($a)) then gs:disp-year($a) else '?', $sep, if (exists($b)) then gs:disp-year($b) else '?')"/>
    </xsl:function>

    <xsl:function name="gs:birth" as="xs:integer?">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="gs:year(($e/tei:birth/tei:date/@when)[1])"/>
    </xsl:function>
    <xsl:function name="gs:death" as="xs:integer?">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="gs:year(($e/tei:death/tei:date/@when)[1])"/>
    </xsl:function>
    <!-- event: last @when / @notBefore / @notAfter of its dates (as build-entities.mjs) -->
    <xsl:function name="gs:event-date" as="xs:integer?">
        <xsl:param name="e" as="element()"/>
        <xsl:param name="attr" as="xs:string"/>
        <xsl:sequence select="gs:year(($e/tei:date/@*[local-name() = $attr])[last()])"/>
    </xsl:function>
    <xsl:function name="gs:pub-year" as="xs:integer?">
        <xsl:param name="e" as="element()"/>
        <xsl:sequence select="gs:year(($e//tei:date[@type = 'publication']/@when)[1])"/>
    </xsl:function>
    <xsl:function name="gs:foundation" as="xs:integer?">
        <xsl:param name="e" as="element()"/>
        <xsl:variable name="d" select="($e/tei:event[@type = 'foundation']//tei:date)[1]"/>
        <xsl:sequence select="if ($d) then gs:year(($d/@when, $d/@notBefore, string($d))[1]) else ()"/>
    </xsl:function>

    <!-- ============================ page shell ============================ -->

    <!-- common page: shared head/navbar/footer + the register style sheets and scripts -->
    <xsl:template name="gs:page">
        <xsl:param name="title" as="xs:string"/>
        <xsl:param name="body_class" as="xs:string"/>
        <xsl:param name="main_class" as="xs:string" select="'container gs-main'"/>
        <xsl:param name="css" as="xs:string*" select="()"/>
        <xsl:param name="content"/>
        <xsl:param name="scripts"/>
        <html lang="fr">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="concat($title, ' — ', $project_short_title)"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
                <xsl:for-each select="$css">
                    <link rel="stylesheet" href="{.}"/>
                </xsl:for-each>
                <link rel="stylesheet" href="css/registres.css"/>
            </head>
            <body class="d-flex flex-column min-vh-100 {$body_class}">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="{$main_class} flex-grow-1">
                    <xsl:copy-of select="$content"/>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
                <xsl:copy-of select="$scripts"/>
            </body>
        </html>
    </xsl:template>

    <xsl:template name="gs:exp-badge">
        <span class="gs-exp-badge" title="{$gs:exp-title}">exp.</span>
    </xsl:template>

    <!-- reconciliation badge: glyph (decorative) + words, never colour alone -->
    <xsl:template name="gs:conf-badge">
        <xsl:param name="conf" as="xs:string"/>
        <xsl:variable name="glyph" select="if ($conf = 'high') then '◆◆◆' else if ($conf = 'medium') then '◆◆' else if ($conf = 'low') then '◆' else '○'"/>
        <xsl:variable name="text" select="if ($conf = 'none') then 'non réconciliée' else concat('réconciliation automatique — ', gs:conf-fr($conf))"/>
        <span class="gs-conf gs-conf-{$conf}">
            <span class="gs-conf-glyph" aria-hidden="true"><xsl:value-of select="$glyph"/></span>
            <span class="gs-conf-text"><xsl:value-of select="$text"/></span>
        </span>
    </xsl:template>
</xsl:stylesheet>
