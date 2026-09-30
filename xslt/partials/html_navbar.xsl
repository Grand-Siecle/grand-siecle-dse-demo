<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="2.0">
    <xsl:template name="nav_bar">
        <a class="visually-hidden-focusable" href="#main">Aller au contenu</a>
        <header>
            <nav aria-label="Navigation principale" class="navbar navbar-expand-lg gs-navbar" data-bs-theme="dark">
                <div class="container-fluid">
                    <a class="navbar-brand gs-brand" href="index.html" aria-label="{$project_short_title}">
                        <span class="gs-brand-grand">Grand</span><xsl:text> </xsl:text><span class="gs-brand-siecle">Siècle</span>
                    </a>
                    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Afficher la navigation">
                        <span class="navbar-toggler-icon"></span>
                    </button>
                    <div class="collapse navbar-collapse" id="navbarSupportedContent">
                        <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                            <li class="nav-item dropdown">
                                <a class="nav-link dropdown-toggle" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">Projet</a>
                                <ul class="dropdown-menu">
                                    <li>
                                        <a class="dropdown-item" href="about.html">À propos</a>
                                    </li>
                                    <li>
                                        <a class="dropdown-item" href="imprint.html">Mentions légales</a>
                                    </li>
                                </ul>
                            </li>

                            <li class="nav-item">
                                <a class="nav-link" href="toc.html">Table des matières</a>
                            </li>

                            <li class="nav-item dropdown">
                                <a class="nav-link dropdown-toggle" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">Registres</a>
                                <ul class="dropdown-menu">
                                    <li>
                                        <a class="dropdown-item" href="listperson.html">Personnes</a>
                                    </li>
                                    <li>
                                        <a class="dropdown-item" href="listplace.html">Lieux</a>
                                    </li>
                                    <li>
                                        <a class="dropdown-item" href="listorg.html">Organisations</a>
                                    </li>
                                    <li>
                                        <a class="dropdown-item" href="listbibl.html">Œuvres</a>
                                    </li>
                                    <li><hr class="dropdown-divider"/></li>
                                    <li><a class="dropdown-item" href="listevent.html">Événements</a></li>
                                    <li><a class="dropdown-item" href="listartwork.html">Objets et œuvres d'art</a></li>
                                    <li><a class="dropdown-item" href="listmaterial.html">Matériaux</a></li>
                                    <li><a class="dropdown-item" href="listtechnique.html">Techniques</a></li>
                                    <li><a class="dropdown-item" href="listdate.html">Dates</a></li>
                                </ul>
                            </li>
                            <li class="nav-item">
                                <a title="API" class="nav-link" href="api.xml">API</a>
                            </li>
                        </ul>
                    </div>
                </div>
            </nav>
        </header>
    </xsl:template>
</xsl:stylesheet>