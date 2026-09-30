<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs"
    version="2.0">

        <xsl:import href="./partials/params.xsl"/>
        <xsl:output media-type="text" encoding="UTF-8" omit-xml-declaration="yes"/>
        <xsl:template match="/">#FORMAT: BEACON<xsl:text>&#xa;</xsl:text>#NAME:<xsl:value-of select="$project_title"/><xsl:for-each select=".//tei:person[.//tei:idno[@type='gnd']/text()]"><xsl:text>&#xa;</xsl:text><xsl:value-of select=".//tei:idno[@type='gnd']/text()"/>|<xsl:value-of select="normalize-space((tei:persName[@type='standard'], tei:persName)[1])"/>|<xsl:value-of select="concat($base_url, @xml:id, '.html')"/></xsl:for-each>
    </xsl:template>
</xsl:stylesheet>