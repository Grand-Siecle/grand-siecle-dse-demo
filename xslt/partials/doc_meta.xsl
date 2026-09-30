<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: helpers reading the teiHeader of an edition (used by index.xsl, toc.xsl and
    editions.xsl), and the document card shared by the home page and the Corpus page.
    Same data and wording as the MaX edition (xq/toc.xq, fragments/fr/accueil.frag.html).
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gsdoc="urn:grand-siecle:doc"
    exclude-result-prefixes="#all"
    version="2.0">

    <!-- the editions present in data/editions (TEI files as they are), ordered by imprint date
         (as the MaX Corpus page) -->
    <xsl:function name="gsdoc:editions" as="element(tei:TEI)*">
        <xsl:for-each select="collection('../../data/editions?select=*.xml')/tei:TEI">
            <xsl:sort select="normalize-space(tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:date[1])"/>
            <xsl:sequence select="."/>
        </xsl:for-each>
    </xsl:function>

    <!-- document id from the file name: LIV0019_reconciled.tei.xml (Grand Siecle naming) or
         LIV0019.xml -> LIV0019; the page names (LIV0019.html, LIV0019-page-41.html) derive from it.
         TEI/@xml:id is not used: it is left as the project wrote it. -->
    <xsl:function name="gsdoc:id-from-uri" as="xs:string">
        <xsl:param name="uri" as="xs:string"/>
        <xsl:sequence select="replace(tokenize($uri, '/')[last()], '(_reconciled)?(\.tei)?\.xml$', '')"/>
    </xsl:function>
    <xsl:function name="gsdoc:id" as="xs:string">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:sequence select="gsdoc:id-from-uri(string(document-uri(root($tei))))"/>
    </xsl:function>

    <!-- Display rule, not a correction of the TEI: the teiHeader of LIV0001 gives the author's
         forename as "s" (error of the upstream conversion); the site shows "Judocus", as the MaX
         edition does (scripts/prepare-tei.mjs, AUTHOR_NAME_OVERRIDES). To be removed once the
         source is fixed. Same rule in pyscripts/make_ts_index.py (AUTHOR_FORENAME_FIXES). -->
    <xsl:variable name="gsdoc:forename-fixes" as="element()*">
        <fix doc="LIV0001" forename="Judocus"/>
    </xsl:variable>

    <xsl:function name="gsdoc:name" as="xs:string">
        <xsl:param name="pn" as="element()?"/>
        <xsl:sequence select="normalize-space(string-join(($pn/tei:forename, $pn/tei:surname), ' '))"/>
    </xsl:function>

    <!-- publishers of the imprint (bibl/respStmt); $resp restricts to one role (e.g. 'Libraire') -->
    <xsl:function name="gsdoc:publishers" as="xs:string*">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:param name="resp" as="xs:string?"/>
        <xsl:sequence select="for $r in $tei/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:respStmt
            [empty($resp) or normalize-space(tei:resp) = $resp] return gsdoc:name($r/tei:persName[1])"/>
    </xsl:function>

    <!-- language codes ordered by usage: ('fra', 'lat') -->
    <xsl:function name="gsdoc:langs" as="xs:string*">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:for-each select="$tei/tei:teiHeader/tei:profileDesc/tei:langUsage/tei:language">
            <xsl:sort select="xs:integer((@usage, 0)[1])" order="descending"/>
            <xsl:sequence select="string(@ident)"/>
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="gsdoc:date" as="xs:string">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:sequence select="normalize-space($tei/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:date[1])"/>
    </xsl:function>

    <!-- "Forename Surname" of the titleStmt author (display rule above applied) -->
    <xsl:template name="doc_author">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:variable name="pn" select="$tei/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[1]/tei:persName"/>
        <xsl:variable name="fix" select="$gsdoc:forename-fixes[@doc = gsdoc:id($tei)]/@forename"/>
        <xsl:value-of select="if ($fix and $pn) then normalize-space(string-join(($fix, $pn/tei:surname), ' ')) else gsdoc:name($pn)"/>
    </xsl:template>

    <!-- Imprint date of the printed source -->
    <xsl:template name="doc_date">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:value-of select="gsdoc:date($tei)"/>
    </xsl:template>

    <!-- Languages ordered by usage, French labels: "latin, français" -->
    <xsl:template name="doc_languages">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:value-of select="string-join(for $l in gsdoc:langs($tei) return
            (('français', 'latin', 'grec ancien')[index-of(('fra', 'lat', 'grc'), $l)], $l)[1], ', ')"/>
    </xsl:template>

    <!-- Number of printed pages (= tei:pb in the text) -->
    <xsl:template name="doc_page_count">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:value-of select="count($tei/tei:text//tei:pb)"/>
    </xsl:template>

    <!--
        Document card (MaX gs-doc-card).
        variant 'home':   "LIV0017 · 166 images [· latin]", author ", trad. X", "Paris, <libraires joined by &>"
        variant 'corpus': "LIV0017", author, "Paris, chez <all publishers joined by ·>", then "163 pages · fra, lat"
    -->
    <xsl:template name="doc_card">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:param name="variant" as="xs:string" select="'corpus'"/>
        <xsl:param name="heading" as="xs:string" select="'h3'"/>
        <xsl:variable name="id" select="gsdoc:id($tei)"/>
        <xsl:variable name="fileDesc" select="$tei/tei:teiHeader/tei:fileDesc"/>
        <xsl:variable name="bibl" select="$fileDesc/tei:sourceDesc/tei:bibl"/>
        <xsl:variable name="langs" select="gsdoc:langs($tei)"/>
        <xsl:variable name="author">
            <xsl:call-template name="doc_author"><xsl:with-param name="tei" select="$tei"/></xsl:call-template>
        </xsl:variable>
        <a class="gs-doc-card" href="{$id}.html">
            <span class="gs-doc-id">
                <xsl:value-of select="$id"/>
                <xsl:if test="$variant = 'home'">
                    <xsl:variable name="images" select="string($fileDesc/tei:extent/tei:measure[@unit = 'images'][1]/@n)"/>
                    <xsl:if test="$images != ''"><xsl:value-of select="concat(' · ', $images, ' images')"/></xsl:if>
                    <xsl:if test="$langs[1] = 'lat'"> · latin</xsl:if>
                </xsl:if>
            </span>
            <xsl:element name="{$heading}">
                <xsl:attribute name="class" select="'gs-browse-title'"/>
                <xsl:value-of select="normalize-space($fileDesc/tei:titleStmt/tei:title[1])"/>
            </xsl:element>
            <span class="gs-browse-meta">
                <span class="gs-browse-author">
                    <xsl:value-of select="$author"/>
                    <xsl:if test="$variant = 'home'">
                        <xsl:for-each select="$fileDesc/tei:titleStmt/tei:editor[@role = 'translator'][1]">
                            <xsl:value-of select="concat(', trad. ', gsdoc:name(tei:persName))"/>
                        </xsl:for-each>
                    </xsl:if>
                </span>
                <span class="gs-browse-place">
                    <xsl:value-of select="normalize-space($bibl/tei:pubPlace[1])"/>
                    <xsl:choose>
                        <xsl:when test="$variant = 'home'">
                            <xsl:variable name="libraires" select="gsdoc:publishers($tei, 'Libraire')"/>
                            <xsl:if test="exists($libraires)"><xsl:value-of select="concat(', ', string-join($libraires, ' &amp; '))"/></xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:variable name="all" select="gsdoc:publishers($tei, ())"/>
                            <xsl:if test="exists($all)"><xsl:value-of select="concat(', chez ', string-join($all, ' · '))"/></xsl:if>
                        </xsl:otherwise>
                    </xsl:choose>
                </span>
                <span class="gs-browse-date"><xsl:value-of select="gsdoc:date($tei)"/></span>
            </span>
            <xsl:if test="$variant = 'corpus'">
                <span class="gs-doc-stats">
                    <xsl:value-of select="count($tei/tei:text//tei:pb)"/>
                    <xsl:text> pages · </xsl:text>
                    <xsl:value-of select="string-join($langs, ', ')"/>
                </span>
            </xsl:if>
        </a>
    </xsl:template>
</xsl:stylesheet>
