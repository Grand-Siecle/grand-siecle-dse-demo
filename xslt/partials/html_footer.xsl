<?xml version="1.0" encoding="UTF-8"?>
<!--
    Grand Siecle: site footer, same content and layout as the MaX edition (gs-footer),
    with the publishing tool credited exactly (dse-static-cookiecutter, ACDH-CH).

    Template html_footer (name kept stable, called by every page):
      bootstrap_js   load jQuery + the Bootstrap bundle (default true(), as in the template,
                     for the pages that use Bootstrap modals or Tabulator); the pages built by
                     index/toc/meta/imprint/404/search/editions pass false(): they need no
                     library (menu and dropdown work with <details> and js/gs-nav.js)
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all"
    version="2.0">
    <xsl:template name="html_footer">
        <xsl:param name="bootstrap_js" as="xs:boolean" select="true()"/>
        <footer class="gs-footer">
            <div>
                <span class="gs-footer-title">Grand Siècle</span>
                <span class="gs-footer-sep" aria-hidden="true">|</span>
                <span>Universités de Lausanne (UNIL) et de Genève (UNIGE)</span>
            </div>
            <div class="gs-footer-line">
                <a href="toc.html">Corpus</a>
                <span class="gs-footer-sep" aria-hidden="true">·</span>
                <a href="entites.html">Entités</a>
                <span class="gs-footer-sep" aria-hidden="true">·</span>
                <a href="search.html">Recherche</a>
                <span class="gs-footer-sep" aria-hidden="true">·</span>
                <a href="about.html">À propos</a>
                <span class="gs-footer-sep" aria-hidden="true">·</span>
                <a href="imprint.html">Mentions légales</a>
            </div>
            <div class="gs-footer-line">
                <span>Textes et données sous licence
                    <a href="https://creativecommons.org/licenses/by/4.0/deed.fr" rel="license">CC BY 4.0</a></span>
                <span class="gs-footer-sep" aria-hidden="true">|</span>
                <span>Édition réalisée avec
                    <a href="https://github.com/acdh-oeaw/dse-static-cookiecutter">dse-static-cookiecutter</a>
                    — ACDH-CH, Académie autrichienne des sciences</span>
            </div>
        </footer>
        <xsl:if test="$bootstrap_js">
            <script src="vendor/jquery/jquery-3.7.1.min.js"></script>
            <script src="vendor/bootstrap-5.3.5-dist/js/bootstrap.bundle.min.js"></script>
        </xsl:if>
    </xsl:template>
</xsl:stylesheet>
