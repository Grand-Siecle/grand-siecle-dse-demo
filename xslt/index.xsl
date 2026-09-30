<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: home page, same layout and wording as the MaX edition
    (fragments/fr/accueil.frag.html): hero (kicker, two-tone title, text, two buttons,
    three key figures, framed portrait), "Le corpus" (one card per edition) and the dark
    "Entrer dans le corpus autrement" section.
    Unlike MaX, where the home fragment is hand written, the cards and the key figures are
    computed at build time from the TEI (data/editions) and the registers (data/indices).
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:gsdoc="urn:grand-siecle:doc"
    version="2.0"
    exclude-result-prefixes="#all">

    <xsl:import href="./partials/html_head.xsl"/>
    <xsl:import href="./partials/html_navbar.xsl"/>
    <xsl:import href="./partials/html_footer.xsl"/>
    <xsl:import href="./partials/doc_meta.xsl"/>
    <xsl:output encoding="UTF-8" media-type="text/html" method="html" version="5.0" indent="yes" omit-xml-declaration="yes"/>

    <xsl:template match="/">
        <xsl:variable name="editions" select="gsdoc:editions()"/>
        <xsl:variable name="registers" select="collection('../data/indices?select=list*.xml')"/>
        <xsl:variable name="years" select="for $t in $editions return xs:integer(replace(gsdoc:date($t), '^.*?([0-9]{4}).*$', '$1'))"/>
        <html lang="{$default_lang}">
            <head>
                <xsl:call-template name="html_head">
                    <xsl:with-param name="html_title" select="$project_short_title"/>
                    <xsl:with-param name="bootstrap_icons" select="false()"/>
                </xsl:call-template>
            </head>
            <body class="d-flex flex-column min-vh-100">
                <xsl:call-template name="nav_bar"/>
                <main id="main" tabindex="-1" class="container gs-main flex-grow-1">
                    <div id="gs-accueil">
                        <section class="gs-hero" aria-labelledby="gs-hero-title">
                            <div class="gs-hero-inner">
                                <div class="gs-hero-content gs-reveal">
                                    <p class="gs-hero-kicker">XVIe – XVIIe siècle</p>
                                    <h1 class="gs-hero-title" id="gs-hero-title">
                                        <span class="gs-hero-title-grand">Grand</span>
                                        <xsl:text> </xsl:text>
                                        <span class="gs-hero-title-siecle">Siècle</span>
                                    </h1>
                                    <p class="gs-hero-subtitle">Qu'est-ce qu'une bonne peinture ? Explorer les premiers
                                        discours français sur la peinture et les arts au XVIIe siècle : cinq imprimés
                                        transcrits, modernisés et annotés, reliés à un index d'entités réconciliées
                                        avec Wikidata.</p>
                                    <div class="gs-hero-cta">
                                        <a class="gs-btn gs-btn-primary" href="toc.html">Explorer le corpus</a>
                                        <a class="gs-btn gs-btn-ghost" href="about.html">À propos de la démo</a>
                                    </div>
                                    <div class="gs-hero-stats">
                                        <span class="gs-stat">
                                            <span class="gs-stat-value"><xsl:value-of select="count($editions)"/></span>
                                            <span class="gs-stat-label">documents</span>
                                        </span>
                                        <span class="gs-stat">
                                            <span class="gs-stat-value"><xsl:value-of select="count($registers)"/></span>
                                            <span class="gs-stat-label">registres d'entités</span>
                                        </span>
                                        <span class="gs-stat">
                                            <span class="gs-stat-value"><xsl:value-of select="concat(min($years), ' – ', max($years))"/></span>
                                            <span class="gs-stat-label">éditions parisiennes</span>
                                        </span>
                                    </div>
                                </div>
                                <figure class="gs-hero-visual">
                                    <div class="gs-hero-frame">
                                        <img class="gs-hero-painting" src="images/poussin-autoportrait.jpg" width="960" height="1250"
                                            alt="Nicolas Poussin, Autoportrait, 1650, musée du Louvre"/>
                                        <span class="gs-hero-frame-border"></span>
                                    </div>
                                    <figcaption class="gs-hero-credit">Nicolas Poussin, Autoportrait, 1650 — musée du Louvre (domaine public)</figcaption>
                                </figure>
                            </div>
                        </section>

                        <section class="gs-section" id="corpus" aria-labelledby="gs-corpus-title">
                            <p class="gs-section-kicker">Le corpus</p>
                            <h2 class="gs-section-title" id="gs-corpus-title">Cinq imprimés du XVIIe siècle</h2>
                            <p class="gs-section-intro">Transcriptions issues d'HTR, avec double couche
                                originale / modernisée, analyse linguistique mot à mot et entités nommées
                                détectées automatiquement puis réconciliées.</p>
                            <div class="gs-doc-grid">
                                <xsl:for-each select="$editions">
                                    <xsl:call-template name="doc_card">
                                        <xsl:with-param name="tei" select="."/>
                                        <xsl:with-param name="variant" select="'home'"/>
                                    </xsl:call-template>
                                </xsl:for-each>
                            </div>
                        </section>

                        <section class="gs-section-explore" id="explorer" aria-labelledby="gs-explore-title">
                            <p class="gs-section-kicker">Explorer</p>
                            <h2 class="gs-section-title" id="gs-explore-title">Entrer dans le corpus autrement</h2>
                            <div class="gs-explore-grid">
                                <a class="gs-explore-card" href="entites.html">
                                    <h3>Entités</h3>
                                    <p>Personnes, lieux, œuvres… neuf registres d'autorité issus de la détection
                                        automatique (NER) et de la réconciliation Wikidata.</p>
                                </a>
                                <a class="gs-explore-card" href="carte.html">
                                    <h3>Carte</h3>
                                    <p>Les lieux cités dans le corpus, géolocalisés sur une carte interactive.</p>
                                </a>
                                <a class="gs-explore-card" href="chronologie.html">
                                    <h3>Chronologie</h3>
                                    <p>Une frise des vies des personnes citées et des événements datés.</p>
                                </a>
                                <a class="gs-explore-card" href="search.html">
                                    <h3>Recherche</h3>
                                    <p>Recherche en plein texte dans les transcriptions des cinq documents.</p>
                                </a>
                            </div>
                            <p class="gs-demo-note">Démonstrateur : cette édition « Grand Siècle » est publiée avec
                                le gabarit dse-static-cookiecutter (ACDH-CH, Académie autrichienne des sciences) :
                                pages HTML statiques produites par XSLT, recherche servie par Typesense.
                                Version de travail, non publique.</p>
                        </section>
                    </div>
                </main>
                <xsl:call-template name="html_footer">
                    <xsl:with-param name="bootstrap_js" select="false()"/>
                </xsl:call-template>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
