<?xml version="1.0" encoding="UTF-8"?>
<!-- Entity detail blocks (modal bodies and entity pages), adapted to the Grand Siecle registers:
     names typed main/standard/variant, dates in @when, note[@type='description'], typed idno,
     back-links in noteGrp/note[@type='mentions'] (added by pyscripts/import_data.py). -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    version="2.0" exclude-result-prefixes="xsl tei xs">

    <!-- authority identifiers as links -->
    <xsl:template name="idnos">
        <xsl:if test="./tei:idno">
            <dt>Identifiants</dt>
            <xsl:for-each select="./tei:idno">
                <xsl:variable name="v" select="normalize-space(.)"/>
                <xsl:variable name="url" select="
                    if (matches($v, '^https?://')) then $v
                    else if (@type = 'wikidata') then concat('https://www.wikidata.org/wiki/', $v)
                    else if (@type = 'geonames') then concat('https://www.geonames.org/', $v)
                    else if (@type = 'viaf') then concat('https://viaf.org/viaf/', $v)
                    else if (@type = 'gnd') then concat('https://d-nb.info/gnd/', $v)
                    else if (@type = 'isni') then concat('https://isni.org/isni/', $v)
                    else if (@type = 'bnf') then concat('https://catalogue.bnf.fr/ark:/12148/cb', $v)
                    else ''"/>
                <dd>
                    <xsl:value-of select="@type"/>
                    <xsl:text> : </xsl:text>
                    <xsl:choose>
                        <xsl:when test="$url != ''"><a href="{$url}"><xsl:value-of select="$v"/></a></xsl:when>
                        <xsl:otherwise><xsl:value-of select="$v"/></xsl:otherwise>
                    </xsl:choose>
                </dd>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>

    <xsl:template name="description">
        <xsl:if test="./tei:note[@type = 'description']">
            <dt>Description (Wikidata)</dt>
            <dd><xsl:value-of select="./tei:note[@type = 'description']"/></dd>
        </xsl:if>
    </xsl:template>

    <xsl:template name="names">
        <xsl:param name="names"/>
        <xsl:if test="$names[@type = 'standard']">
            <dt>Forme normalisée</dt>
            <dd><xsl:value-of select="$names[@type = 'standard'][1]"/></dd>
        </xsl:if>
        <xsl:if test="$names[@type = 'variant']">
            <dt>Formes attestées</dt>
            <dd><xsl:value-of select="string-join($names[@type = 'variant'], ' · ')"/></dd>
        </xsl:if>
    </xsl:template>

    <xsl:template name="mentions">
        <xsl:if test="./tei:noteGrp/tei:note[@type = 'mentions']">
            <dt>Cité dans</dt>
            <xsl:for-each select="./tei:noteGrp/tei:note[@type = 'mentions']">
                <dd>
                    <a href="{replace(@target, '\.xml$', '.html')}">
                        <xsl:value-of select="./text()"/>
                    </a>
                </dd>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>

    <xsl:template match="tei:bibl" name="bibl_detail">
        <dl>
            <xsl:call-template name="names"><xsl:with-param name="names" select="./tei:title"/></xsl:call-template>
            <xsl:if test="./tei:author">
                <dt>Auteur</dt>
                <xsl:for-each select="./tei:author">
                    <dd><xsl:value-of select="normalize-space(.)"/></dd>
                </xsl:for-each>
            </xsl:if>
            <xsl:if test="./tei:textLang">
                <dt>Langue</dt>
                <dd><xsl:value-of select="./tei:textLang[1]"/></dd>
            </xsl:if>
            <xsl:call-template name="description"/>
            <xsl:call-template name="idnos"/>
            <xsl:call-template name="mentions"/>
        </dl>
    </xsl:template>

    <xsl:template match="tei:org" name="org_detail">
        <dl>
            <xsl:call-template name="names"><xsl:with-param name="names" select="./tei:orgName"/></xsl:call-template>
            <xsl:call-template name="description"/>
            <xsl:call-template name="idnos"/>
            <xsl:call-template name="mentions"/>
        </dl>
    </xsl:template>

    <xsl:template match="tei:person" name="person_detail">
        <dl>
            <xsl:call-template name="names"><xsl:with-param name="names" select="./tei:persName"/></xsl:call-template>
            <xsl:if test="./tei:birth/tei:date">
                <dt>Naissance</dt>
                <dd><xsl:value-of select="(./tei:birth/tei:date/@when, ./tei:birth/tei:date)[1]"/></dd>
            </xsl:if>
            <xsl:if test="./tei:death/tei:date">
                <dt>Mort</dt>
                <dd><xsl:value-of select="(./tei:death/tei:date/@when, ./tei:death/tei:date)[1]"/></dd>
            </xsl:if>
            <xsl:if test="./tei:occupation">
                <dt>Activités</dt>
                <dd><xsl:value-of select="string-join(./tei:occupation, ', ')"/></dd>
            </xsl:if>
            <xsl:call-template name="description"/>
            <xsl:call-template name="idnos"/>
            <xsl:call-template name="mentions"/>
        </dl>
    </xsl:template>

    <xsl:template match="tei:place" name="place_detail">
        <dl>
            <xsl:call-template name="names"><xsl:with-param name="names" select="./tei:placeName"/></xsl:call-template>
            <xsl:if test="./tei:country">
                <dt>Pays</dt>
                <dd><xsl:value-of select="./tei:country[1]"/></dd>
            </xsl:if>
            <xsl:if test="./tei:location/tei:geo">
                <dt>Coordonnées (lat., long.)</dt>
                <dd><xsl:value-of select="replace(normalize-space(./tei:location[1]/tei:geo[1]), ' ', ', ')"/></dd>
            </xsl:if>
            <xsl:call-template name="description"/>
            <xsl:call-template name="idnos"/>
            <xsl:call-template name="mentions"/>
        </dl>
    </xsl:template>
</xsl:stylesheet>
