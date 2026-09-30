<?xml version="1.0" encoding="UTF-8"?>
<!-- Grand Siecle: helpers reading the teiHeader of an edition (used by toc.xsl and editions.xsl). -->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all"
    version="2.0">

    <!-- "Forename Surname" of the titleStmt author -->
    <xsl:template name="doc_author">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:variable name="pn" select="$tei/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author[1]/tei:persName"/>
        <xsl:value-of select="normalize-space(string-join(($pn/tei:forename, $pn/tei:surname), ' '))"/>
    </xsl:template>

    <!-- Imprint date of the printed source -->
    <xsl:template name="doc_date">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:value-of select="normalize-space($tei/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:date[1])"/>
    </xsl:template>

    <!-- Languages ordered by usage, French labels: "latin, français" -->
    <xsl:template name="doc_languages">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:variable name="sorted" as="xs:string*">
            <xsl:for-each select="$tei/tei:teiHeader/tei:profileDesc/tei:langUsage/tei:language">
                <xsl:sort select="xs:integer((@usage, 0)[1])" order="descending"/>
                <xsl:sequence select="(self::*[@ident = 'fra']/'français', self::*[@ident = 'lat']/'latin',
                    self::*[@ident = 'grc']/'grec ancien', string(@ident))[1]"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="string-join($sorted, ', ')"/>
    </xsl:template>

    <!-- Number of printed pages (= tei:pb in the text) -->
    <xsl:template name="doc_page_count">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:value-of select="count($tei/tei:text//tei:pb)"/>
    </xsl:template>
</xsl:stylesheet>
