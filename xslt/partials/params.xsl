<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gs="urn:grand-siecle"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    exclude-result-prefixes="#all">
    <!-- documents present in data/editions, as listed by the file derived at build time
         (pyscripts/derive_mentions.py): the counts written in running text follow them -->
    <xsl:variable name="gs:corpus-docs" select="doc('../../build/derived/mentions.xml')/mentions/doc"/>

    <!-- French number word for the counts written in running text ("cinq imprimés") -->
    <xsl:function name="gs:number-fr" as="xs:string">
        <xsl:param name="n" as="xs:integer"/>
        <xsl:param name="capital" as="xs:boolean"/>
        <xsl:variable name="w" select="if ($n ge 1 and $n le 10)
            then ('un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix')[$n] else string($n)"/>
        <xsl:sequence select="if ($capital) then concat(upper-case(substring($w, 1, 1)), substring($w, 2)) else $w"/>
    </xsl:function>
    <!-- "cinq imprimés" / "un imprimé" -->
    <xsl:function name="gs:count-fr" as="xs:string">
        <xsl:param name="n" as="xs:integer"/>
        <xsl:param name="noun" as="xs:string"/>
        <xsl:param name="capital" as="xs:boolean"/>
        <xsl:sequence select="concat(gs:number-fr($n, $capital), ' ', $noun, if ($n gt 1 and not(ends-with($noun, 's'))) then 's' else '')"/>
    </xsl:function>

    <xsl:param name="directory_name">grand-siecle-dse</xsl:param>
    <xsl:param name="project_title" select="concat('Grand Siècle — ', gs:count-fr(count($gs:corpus-docs), 'imprimé', false()), ' du XVIIe siècle (démonstration DSE)')"/>
    <!-- meta description, same wording as the MaX edition -->
    <xsl:param name="project_description" select="concat(gs:count-fr(count($gs:corpus-docs), 'discours', true()), ' français sur la peinture au XVIIe siècle : transcriptions, entités, carte et chronologie.')"/>
    <xsl:param name="redmine_id">18716</xsl:param>
    <xsl:param name="project_short_title">Grand Siècle</xsl:param>
    <xsl:param name="default_lang">fr</xsl:param>
    <!-- local, non public demo: no repository link, relative citation URLs -->
    <xsl:param name="github_url"></xsl:param>
    <xsl:param name="html_title">Grand Siècle</xsl:param>
    <xsl:param name="project_logo">images/logo.png</xsl:param>
    <xsl:param name="base_url"></xsl:param>
    <xsl:param name="data_repo">https://github.com/Grand-Siecle/dse-static-data</xsl:param>
</xsl:stylesheet>
