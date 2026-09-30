<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    <xsl:template name="tabulator_dl_buttons">
        <h4>Télécharger le tableau</h4>
        <div class="button-group">
            <button type="button" class="btn btn-outline-secondary" id="download-csv" title="Télécharger en CSV">
                <i class="bi bi-filetype-csv"></i>
                <span class="visually-hidden">Télécharger en CSV</span>
            </button>
            <button type="button" class="btn btn-outline-secondary" id="download-json" title="Télécharger en JSON">
                <i class="bi bi-filetype-json"></i>
                <span class="visually-hidden">Télécharger en JSON</span>
            </button>
            <button type="button" class="btn btn-outline-secondary" id="download-html" title="Télécharger en HTML">
                <i class="bi bi-filetype-html"></i>
                <span class="visually-hidden">Télécharger en HTML</span>
            </button>
        </div>
    </xsl:template>
</xsl:stylesheet>