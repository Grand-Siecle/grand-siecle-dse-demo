<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: site header, identical to the canonical gs-header of the MaX edition
    (ui/templates/template.html + ui/xsl/core/menu.xsl): brand "GRAND Siècle", main menu
    Accueil / Corpus / Recherche / Entités (dropdown of the nine registers) / Carte /
    Chronologie / À propos, active entry, burger menu under 900px (js/gs-nav.js).

    Template nav_bar (name kept stable, called by every page):
      active     section to highlight ('accueil', 'corpus', 'recherche', 'entites', 'carte',
                 'chronologie', 'about' or ''); by default derived from the output file name
      page_nav   optional controls shown in the header bar (page navigation of the reading pages)
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gsnav="urn:grand-siecle:nav"
    exclude-result-prefixes="#all" version="2.0">

    <!-- the nine registers, in the order of the MaX menu (menu.xml) -->
    <xsl:variable name="gsnav:registers" as="element(entry)*">
        <entry href="listperson.html">Personnes</entry>
        <entry href="listplace.html">Lieux</entry>
        <entry href="listorg.html">Organisations</entry>
        <entry href="listbibl.html">Œuvres</entry>
        <entry href="listevent.html">Événements</entry>
        <entry href="listartwork.html">Objets &amp; œuvres d'art</entry>
        <entry href="listmaterial.html">Matériaux</entry>
        <entry href="listtechnique.html">Techniques</entry>
        <entry href="listdate.html">Dates citées</entry>
    </xsl:variable>

    <xsl:function name="gsnav:section" as="xs:string">
        <xsl:param name="page" as="xs:string"/>
        <xsl:sequence select="
            if ($page = ('index.html', '')) then 'accueil'
            else if ($page = 'toc.html' or matches($page, '^LIV[0-9]+')) then 'corpus'
            else if ($page = 'search.html') then 'recherche'
            else if ($page = 'entites.html' or starts-with($page, 'list')
                or matches($page, '^(person|place|org|work|event|artwork|material|technique|date)-')) then 'entites'
            else if ($page = 'carte.html') then 'carte'
            else if ($page = 'chronologie.html') then 'chronologie'
            else if ($page = 'about.html') then 'about'
            else ''"/>
    </xsl:function>

    <xsl:template name="gsnav:item">
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="href" as="xs:string"/>
        <xsl:param name="label" as="xs:string"/>
        <xsl:param name="active" as="xs:string"/>
        <xsl:param name="page" as="xs:string"/>
        <!-- highlighted for the whole section, aria-current only on the page itself -->
        <li class="gs-nav-item{if ($id = $active) then ' active' else ''}">
            <a class="gs-nav-link" href="{$href}">
                <xsl:if test="$href = $page"><xsl:attribute name="aria-current" select="'page'"/></xsl:if>
                <xsl:value-of select="$label"/>
            </a>
        </li>
    </xsl:template>

    <xsl:template name="nav_bar">
        <!-- file name of the page being written (principal result or xsl:result-document);
             current-output-uri() is absent inside xsl:function, hence computed here -->
        <xsl:param name="page" as="xs:string" select="string(tokenize(string(current-output-uri()), '/')[last()])"/>
        <xsl:param name="active" as="xs:string" select="gsnav:section($page)"/>
        <xsl:param name="page_nav" as="node()*" select="()"/>
        <a class="gs-skip-link" href="#main">Aller au contenu</a>
        <header id="topbar" class="gs-header">
            <div class="gs-menubar">
                <a class="gs-brand" href="index.html" aria-label="{$project_short_title} — accueil">
                    <span class="gs-brand-grand">Grand</span><span class="gs-brand-siecle">Siècle</span>
                </a>
                <nav class="gs-menu gs-nav" aria-label="Navigation principale">
                    <button class="gs-nav-toggler" type="button" aria-controls="gsNavContent" aria-expanded="false" aria-label="Afficher la navigation">☰</button>
                    <div class="gs-nav-collapse" id="gsNavContent">
                        <ul class="gs-nav-list">
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'accueil'"/><xsl:with-param name="href" select="'index.html'"/>
                                <xsl:with-param name="label" select="'Accueil'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'corpus'"/><xsl:with-param name="href" select="'toc.html'"/>
                                <xsl:with-param name="label" select="'Corpus'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'recherche'"/><xsl:with-param name="href" select="'search.html'"/>
                                <xsl:with-param name="label" select="'Recherche'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                            <li class="gs-nav-item gs-nav-item-dropdown{if ($active = 'entites') then ' active' else ''}">
                                <details class="gs-nav-dropdown">
                                    <summary>
                                        <a class="gs-nav-link" href="entites.html">
                                            <xsl:if test="$page = 'entites.html'"><xsl:attribute name="aria-current" select="'page'"/></xsl:if>
                                            <xsl:text>Entités</xsl:text>
                                        </a>
                                        <span class="gs-nav-caret" aria-hidden="true">▾</span>
                                        <span class="visually-hidden">(afficher les registres)</span>
                                    </summary>
                                    <ul class="gs-nav-submenu">
                                        <xsl:for-each select="$gsnav:registers">
                                            <li>
                                                <a class="gs-nav-sublink{if (@href = $page) then ' active' else ''}" href="{@href}">
                                                    <xsl:if test="@href = $page"><xsl:attribute name="aria-current" select="'page'"/></xsl:if>
                                                    <xsl:value-of select="."/>
                                                </a>
                                            </li>
                                        </xsl:for-each>
                                    </ul>
                                </details>
                            </li>
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'carte'"/><xsl:with-param name="href" select="'carte.html'"/>
                                <xsl:with-param name="label" select="'Carte'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'chronologie'"/><xsl:with-param name="href" select="'chronologie.html'"/>
                                <xsl:with-param name="label" select="'Chronologie'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                            <xsl:call-template name="gsnav:item">
                                <xsl:with-param name="id" select="'about'"/><xsl:with-param name="href" select="'about.html'"/>
                                <xsl:with-param name="label" select="'À propos'"/><xsl:with-param name="active" select="$active"/>
                                <xsl:with-param name="page" select="$page"/>
                            </xsl:call-template>
                        </ul>
                    </div>
                </nav>
                <xsl:if test="exists($page_nav)">
                    <div class="gs-navigation-wrap"><xsl:sequence select="$page_nav"/></div>
                </xsl:if>
            </div>
        </header>
    </xsl:template>
</xsl:stylesheet>
