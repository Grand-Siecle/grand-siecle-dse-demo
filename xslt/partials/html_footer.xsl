<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 

    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="#all"
    version="2.0">
    <xsl:template name="html_footer">
        <footer class="py-3 bg-body-tertiary">
            <div class="text-center">
                <xsl:if test="$github_url != ''">
                    <a href="{$github_url}">
                        <i aria-hidden="true" class="bi bi-github fs-2"></i>
                        <span class="visually-hidden">Dépôt GitHub</span>
                    </a>
                </xsl:if>
                <p class="small mb-0">Projet Grand Siècle (UNIL) · démonstration non publique · <a href="imprint.html">mentions légales</a></p>
            </div>
        </footer>
        <script src="vendor/jquery/jquery-3.7.1.min.js"></script>
        <script src="vendor/bootstrap-5.3.5-dist/js/bootstrap.bundle.min.js"></script>
        
    </xsl:template>
</xsl:stylesheet>