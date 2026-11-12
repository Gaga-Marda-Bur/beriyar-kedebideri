(function () {
    const STORAGE_KEY = "beriya_editor_draft";

    const titleInput = document.getElementById("editorTitle");
    const bodyTextarea = document.getElementById("editorBody");
    const canvasEl = document.getElementById("editorCanvas");
    const statusBadge = document.getElementById("editorStatusBadge");
    const statusText = document.getElementById("editorStatusText");
    const toast = document.getElementById("editorToast");

    let activeInput = bodyTextarea;
    let saveTimeout = null;
    let restoringDraft = false;
    let currentTheme = "dark_forest";
    let currentAlignment = "left";
    let currentFontSize = 24;

    const i18n = window.BERIYA_EDITOR_I18N || {
        saved: "Brouillon enregistré",
        saving: "Sauvegarde...",
        copied: "Texte copié dans le presse-papiers !",
        confirmNew: "Voulez-vous effacer ce texte et commencer un nouveau document ?",
        brand: "Beřiyar Kedebideři",
        website: "beriyarkedebideri.com"
    };

    function showToast(msg) {
        if (!toast) return;
        toast.textContent = msg;
        toast.classList.add("show");
        setTimeout(() => {
            toast.classList.remove("show");
        }, 2500);
    }

    // Load Draft from localStorage
    function loadDraft() {
        restoringDraft = true;
        try {
            const raw = localStorage.getItem(STORAGE_KEY);
            if (!raw) return;
            const draft = JSON.parse(raw);
            if (draft.title !== undefined) titleInput.value = window.BKTransliteration.normalize_erfe(draft.title);
            if (draft.content !== undefined) bodyTextarea.value = window.BKTransliteration.normalize_erfe(draft.content);
            if (draft.theme) setTheme(draft.theme);
            if (draft.alignment) setAlignment(draft.alignment);
            if (draft.fontSize) setFontSize(draft.fontSize);
        } catch (_) {} finally { restoringDraft = false; }
    }

    function saveDraft() {
        if (restoringDraft) return;
        if (statusBadge) statusBadge.classList.add("saving");
        if (statusText) statusText.textContent = i18n.saving;

        clearTimeout(saveTimeout);
        saveTimeout = setTimeout(() => {
            const draft = {
                title: window.BKTransliteration.normalize_erfe(titleInput.value),
                content: window.BKTransliteration.normalize_erfe(bodyTextarea.value),
                theme: currentTheme,
                alignment: currentAlignment,
                fontSize: currentFontSize,
                updatedAt: new Date().toISOString()
            };

            try {
                localStorage.setItem(STORAGE_KEY, JSON.stringify(draft));
            } catch (_) {}

            if (statusBadge) statusBadge.classList.remove("saving");
            if (statusText) statusText.textContent = i18n.saved;
        }, 500);
    }

    function setTheme(theme) {
        currentTheme = theme;
        canvasEl.classList.remove("theme-dark_forest", "theme-cream", "theme-golden", "theme-paper");
        canvasEl.classList.add("theme-" + theme);

        document.querySelectorAll(".theme-dot").forEach((dot) => {
            dot.classList.toggle("active", dot.dataset.theme === theme);
        });
        saveDraft();
    }

    function setAlignment(align) {
        currentAlignment = align;
        canvasEl.classList.remove("align-left", "align-center", "align-right");
        canvasEl.classList.add("align-" + align);

        document.querySelectorAll("[data-align]").forEach((btn) => {
            btn.classList.toggle("active", btn.dataset.align === align);
        });
        saveDraft();
    }

    function setFontSize(size) {
        currentFontSize = parseInt(size, 10);
        bodyTextarea.style.fontSize = currentFontSize + "px";
        titleInput.style.fontSize = Math.round(currentFontSize * 1.25) + "px";

        document.querySelectorAll("[data-size]").forEach((btn) => {
            btn.classList.toggle("active", parseInt(btn.dataset.size, 10) === currentFontSize);
        });
        saveDraft();
    }

    // Input focus tracking for Beriya Virtual Keyboard
    titleInput.addEventListener("focus", () => {
        activeInput = titleInput;
    });

    bodyTextarea.addEventListener("focus", () => {
        activeInput = bodyTextarea;
    });

    titleInput.addEventListener("input", saveDraft);
    bodyTextarea.addEventListener("input", saveDraft);

    // Open Keyboard button
    const openKeyboardBtn = document.getElementById("openBeriyaKeyboardBtn");
    if (openKeyboardBtn) {
        openKeyboardBtn.addEventListener("click", () => {
            if (window.BeriyaKeyboard) {
                window.BeriyaKeyboard.open(activeInput || bodyTextarea);
            }
        });
    }

    // Format Bar Event Listeners
    document.querySelectorAll("[data-align]").forEach((btn) => {
        btn.addEventListener("click", () => setAlignment(btn.dataset.align));
    });

    document.querySelectorAll("[data-size]").forEach((btn) => {
        btn.addEventListener("click", () => setFontSize(btn.dataset.size));
    });

    document.querySelectorAll(".theme-dot").forEach((dot) => {
        dot.addEventListener("click", () => setTheme(dot.dataset.theme));
    });

    // Copy Text
    const copyBtn = document.getElementById("copyTextBtn");
    if (copyBtn) {
        copyBtn.addEventListener("click", () => {
            const title = window.BKTransliteration.normalize_erfe(titleInput.value).trim();
            const body = window.BKTransliteration.normalize_erfe(bodyTextarea.value).trim();
            const full = title ? `${title}\n\n${body}` : body;
            if (!full) return;

            navigator.clipboard.writeText(full).then(() => {
                showToast(i18n.copied);
            }).catch(() => {
                const temp = document.createElement("textarea");
                temp.value = full;
                document.body.appendChild(temp);
                temp.select();
                document.execCommand("copy");
                document.body.removeChild(temp);
                showToast(i18n.copied);
            });
        });
    }

    // New Document
    const newDocBtn = document.getElementById("newDocBtn");
    if (newDocBtn) {
        newDocBtn.addEventListener("click", () => {
            if (confirm(i18n.confirmNew)) {
                titleInput.value = "";
                bodyTextarea.value = "";
                localStorage.removeItem(STORAGE_KEY);
                saveDraft();
            }
        });
    }

    // Print
    const printBtn = document.getElementById("printDocBtn");
    if (printBtn) {
        printBtn.addEventListener("click", () => {
            window.print();
        });
    }

    // ==========================================
    // EXPORT PNG (High DPI Canvas Rendering)
    // ==========================================
    const exportImageBtn = document.getElementById("exportImageBtn");
    if (exportImageBtn) {
        exportImageBtn.addEventListener("click", exportImage);
    }

    async function exportImage() {
        if (document.fonts) {
            await document.fonts.ready;
        }

        const scale = 2; // Retina / high DPI
        const width = 1000 * scale;
        const padding = 50 * scale;

        // Colors per theme
        const themes = {
            dark_forest: { bg: "#0A221A", text: "#FFFFFF", border: "#D4AF37", sub: "rgba(255,255,255,0.7)" },
            cream: { bg: "#FAF6EE", text: "#2B2118", border: "#CBB689", sub: "rgba(43,33,24,0.7)" },
            golden: { bg: "#141913", text: "#FFF7DC", border: "#FFD700", sub: "rgba(255,247,220,0.7)" },
            paper: { bg: "#FFFFFF", text: "#0F172A", border: "#CBD5E1", sub: "rgba(15,23,42,0.7)" }
        };

        const theme = themes[currentTheme] || themes.dark_forest;
        const offscreen = document.createElement("canvas");
        const ctx = offscreen.getContext("2d");

        // Prepare text lines
        const title = window.BKTransliteration.normalize_erfe(titleInput.value).trim();
        const body = window.BKTransliteration.normalize_erfe(bodyTextarea.value);
        const paragraphs = body.split("\n");

        const fontSize = currentFontSize * scale;
        const titleFontSize = Math.round(fontSize * 1.3);
        const lineHeight = fontSize * 1.5;

        // Measure needed height
        ctx.font = `${fontSize}px 'BK Erfe', Inter, sans-serif`;
        const maxWidth = width - (padding * 2);

        function wrapText(text) {
            if (!text.trim()) return [""];
            const words = text.split(" ");
            const lines = [];
            let currentLine = words[0];

            for (let i = 1; i < words.length; i++) {
                const word = words[i];
                const width = ctx.measureText(currentLine + " " + word).width;
                if (width < maxWidth) {
                    currentLine += " " + word;
                } else {
                    lines.push(currentLine);
                    currentLine = word;
                }
            }
            lines.push(currentLine);
            return lines;
        }

        const wrappedLines = [];
        for (const p of paragraphs) {
            wrappedLines.push(...wrapText(p));
        }

        const headerHeight = 70 * scale;
        const titleHeight = title ? (titleFontSize + 24 * scale) : 0;
        const bodyHeight = wrappedLines.length * lineHeight;
        const footerHeight = 60 * scale;

        const totalHeight = padding * 2 + headerHeight + titleHeight + bodyHeight + footerHeight;
        offscreen.width = width;
        offscreen.height = Math.max(totalHeight, 700 * scale);

        // Draw background
        ctx.fillStyle = theme.bg;
        ctx.fillRect(0, 0, width, offscreen.height);

        // Draw border
        ctx.strokeStyle = theme.border;
        ctx.lineWidth = 3 * scale;
        ctx.strokeRect(20 * scale, 20 * scale, width - 40 * scale, offscreen.height - 40 * scale);

        // Draw Header
        ctx.fillStyle = theme.border;
        ctx.font = `bold ${16 * scale}px Inter, sans-serif`;
        ctx.textAlign = "left";
        ctx.fillText("Beřiyar Kedebideři", padding, padding + 20 * scale);

        ctx.textAlign = "right";
        ctx.fillText("✦", width - padding, padding + 20 * scale);

        // Divider
        ctx.strokeStyle = theme.border;
        ctx.globalAlpha = 0.35;
        ctx.lineWidth = 1.5 * scale;
        ctx.beginPath();
        ctx.moveTo(padding, padding + 40 * scale);
        ctx.lineTo(width - padding, padding + 40 * scale);
        ctx.stroke();
        ctx.globalAlpha = 1.0;

        let currentY = padding + headerHeight;

        // Draw Title
        if (title) {
            ctx.fillStyle = theme.text;
            ctx.font = `bold ${titleFontSize}px 'BK Erfe', Inter, sans-serif`;
            ctx.textAlign = currentAlignment;
            const xPos = currentAlignment === "center" ? width / 2 : (currentAlignment === "right" ? width - padding : padding);
            ctx.fillText(title, xPos, currentY + titleFontSize);
            currentY += titleFontSize + 20 * scale;
        }

        // Draw Body
        ctx.fillStyle = theme.text;
        ctx.font = `${fontSize}px 'BK Erfe', Inter, sans-serif`;
        ctx.textAlign = currentAlignment;

        for (const line of wrappedLines) {
            if (line) {
                const xPos = currentAlignment === "center" ? width / 2 : (currentAlignment === "right" ? width - padding : padding);
                ctx.fillText(line, xPos, currentY + fontSize);
            }
            currentY += lineHeight;
        }

        // Footer
        ctx.fillStyle = theme.sub;
        ctx.font = `${11 * scale}px Inter, sans-serif`;
        ctx.textAlign = "right";
        ctx.fillText("beriyarkedebideri.com", width - padding, offscreen.height - padding);

        // Download
        const link = document.createElement("a");
        const cleanName = (title || "Beriya_Document").replace(/[^\w\s\-]/g, "_").replace(/\s+/g, "_");
        link.download = `${cleanName}.png`;
        link.href = offscreen.toDataURL("image/png");
        link.click();
        showToast("Image PNG téléchargée !");
    }

    // ==========================================
    // EXPORT PDF WITH EMBEDDED KEDEBIDERI FONT
    // ==========================================
    const exportPdfBtn = document.getElementById("exportPdfBtn");
    if (exportPdfBtn) {
        exportPdfBtn.addEventListener("click", exportPdf);
    }

    async function exportPdf() {
        showToast("Génération du PDF en cours...");

        try {
            if (typeof PDFLib === "undefined" || typeof fontkit === "undefined") {
                throw new Error("Bibliothèque PDFLib ou fontkit non disponible.");
            }

            // 1. Fetch Kedebideri TTF font binary
            const fontRes = await fetch("/static/webapp/fonts/Kedebideri-Regular.ttf");
            if (!fontRes.ok) throw new Error("Impossible de charger la police Kedebideri-Regular.ttf");
            const fontBytes = await fontRes.arrayBuffer();

            // 2. Create PDFLib document
            const pdfDoc = await PDFLib.PDFDocument.create();
            pdfDoc.registerFontkit(fontkit);

            // 3. Embed TrueType font directly inside the PDF stream!
            const customFont = await pdfDoc.embedFont(fontBytes);
            const fallbackNames = ["NotoSans-Regular.ttf", "NotoSansArabic-Regular.ttf"];
            const fallbackFonts = await Promise.all(fallbackNames.map(async (name) => {
                const response = await fetch(`/static/webapp/fonts/${name}`);
                if (!response.ok) throw new Error(`Impossible de charger ${name}`);
                return pdfDoc.embedFont(await response.arrayBuffer());
            }));
            const choices = [...fallbackFonts, customFont].map(font => ({font, points: new Set(font.getCharacterSet())}));
            const erfeLayoutFont = fontkit.create(new Uint8Array(fontBytes));
            const segments = new Intl.Segmenter(undefined, {granularity: "grapheme"});
            function fontRuns(text) {
                const runs = [];
                for (const {segment} of segments.segment(text)) {
                    const points = Array.from(segment, c => c.codePointAt(0));
                    const choice = choices.find(item => points.every(cp => item.points.has(cp)));
                    if (!choice) throw new Error("Caractère non couvert par les polices PDF.");
                    if (runs.length && runs[runs.length - 1].font === choice.font) runs[runs.length - 1].text += segment;
                    else runs.push({font: choice.font, text: segment});
                }
                return runs;
            }
            function mixedWidth(text, size) {
                return fontRuns(text).reduce((width, run) => width + run.font.widthOfTextAtSize(run.text, size), 0);
            }
            function drawMixed(page, text, options) {
                let x = options.x;
                for (const run of fontRuns(text)) {
                    if (run.font === customFont) {
                        // pdf-lib encodes glyphs but ignores GPOS offsets. Keep
                        // Kedebideri's actual mark anchors when drawing Erfe.
                        const layout = erfeLayoutFont.layout(run.text);
                        const scale = options.size / erfeLayoutFont.unitsPerEm;
                        let advance = 0;
                        layout.glyphs.forEach((glyph, index) => {
                            const position = layout.positions[index];
                            page.drawText(String.fromCodePoint(...glyph.codePoints), {
                                ...options, font:customFont,
                                x:x+(advance+position.xOffset)*scale,
                                y:options.y+position.yOffset*scale,
                            });
                            advance += position.xAdvance;
                        });
                    } else page.drawText(run.text, {...options, x, font: run.font});
                    x += run.font.widthOfTextAtSize(run.text, options.size);
                }
            }
            const helvetica = await pdfDoc.embedFont(PDFLib.StandardFonts.Helvetica);
            const helveticaBold = await pdfDoc.embedFont(PDFLib.StandardFonts.HelveticaBold);

            // A4 dimensions (595.28 x 841.89 pt)
            const pageWidth = 595.28;
            const pageHeight = 841.89;
            const margin = 45;
            const contentWidth = pageWidth - (margin * 2);

            let page = pdfDoc.addPage([pageWidth, pageHeight]);
            let y = pageHeight - margin;

            // Palette
            const goldColor = PDFLib.rgb(0.83, 0.69, 0.22); // #D4AF37
            const darkGreen = PDFLib.rgb(0.05, 0.22, 0.17); // #0D382B
            const textColor = PDFLib.rgb(0.1, 0.1, 0.1);
            const grayColor = PDFLib.rgb(0.5, 0.5, 0.5);

            // Draw Header
            page.drawText("Beriya Kedebideri", {
                x: margin,
                y: y - 10,
                size: 15,
                font: helveticaBold,
                color: darkGreen
            });

            const dateStr = new Date().toLocaleDateString("fr-FR");
            page.drawText(dateStr, {
                x: pageWidth - margin - 60,
                y: y - 10,
                size: 10,
                font: helvetica,
                color: grayColor
            });

            // Gold divider rule
            y -= 22;
            page.drawLine({
                start: { x: margin, y: y },
                end: { x: pageWidth - margin, y: y },
                thickness: 1.5,
                color: goldColor
            });

            y -= 30;

            // Draw Title
            const title = window.BKTransliteration.normalize_erfe(titleInput.value).trim();
            if (title) {
                const titleSize = Math.round(currentFontSize * 1.15);
                drawMixed(page, title, {
                    x: margin,
                    y: y,
                    size: titleSize,
                    font: customFont,
                    color: darkGreen
                });
                y -= (titleSize + 20);
            }

            // Draw Body Paragraphs with multiline wrapping
            const body = window.BKTransliteration.normalize_erfe(bodyTextarea.value).trim();
            const paragraphs = body.split("\n");
            const bodySize = currentFontSize;
            const lineHeight = bodySize * 1.45;

            for (const para of paragraphs) {
                if (!para.trim()) {
                    y -= lineHeight;
                    continue;
                }

                // Simple word wrap
                const words = para.split(" ");
                let currentLine = words[0];

                for (let i = 1; i < words.length; i++) {
                    const testLine = currentLine + " " + words[i];
                    const testWidth = mixedWidth(testLine, bodySize);

                    if (testWidth < contentWidth) {
                        currentLine = testLine;
                    } else {
                        // Check page overflow
                        if (y < margin + 40) {
                            page = pdfDoc.addPage([pageWidth, pageHeight]);
                            y = pageHeight - margin - 30;
                        }

                        drawMixed(page, currentLine, {
                            x: margin,
                            y: y,
                            size: bodySize,
                            font: customFont,
                            color: textColor
                        });
                        y -= lineHeight;
                        currentLine = words[i];
                    }
                }

                // Flush remaining line
                if (currentLine) {
                    if (y < margin + 40) {
                        page = pdfDoc.addPage([pageWidth, pageHeight]);
                        y = pageHeight - margin - 30;
                    }

                    drawMixed(page, currentLine, {
                        x: margin,
                        y: y,
                        size: bodySize,
                        font: customFont,
                        color: textColor
                    });
                    y -= (lineHeight + 6);
                }
            }

            // Draw Footers on all pages
            const pages = pdfDoc.getPages();
            for (let i = 0; i < pages.length; i++) {
                const p = pages[i];
                p.drawLine({
                    start: { x: margin, y: margin + 18 },
                    end: { x: pageWidth - margin, y: margin + 18 },
                    thickness: 0.8,
                    color: PDFLib.rgb(0.85, 0.85, 0.85)
                });

                p.drawText("Beriya Kedebideri - Police Kedebideri incorporee", {
                    x: margin,
                    y: margin + 6,
                    size: 8,
                    font: helvetica,
                    color: grayColor
                });

                p.drawText(`Page ${i + 1} / ${pages.length}`, {
                    x: pageWidth - margin - 50,
                    y: margin + 6,
                    size: 8,
                    font: helvetica,
                    color: grayColor
                });
            }

            // Save PDF and Trigger Download
            const pdfBytes = await pdfDoc.save();
            const blob = new Blob([pdfBytes], { type: "application/pdf" });
            const link = document.createElement("a");
            const cleanTitle = (title || "Document_Beriya").replace(/[^\w\s\-]/g, "_").replace(/\s+/g, "_");
            link.href = URL.createObjectURL(blob);
            link.download = `${cleanTitle}.pdf`;
            link.click();

            showToast("Document PDF généré avec succès !");
        } catch (err) {
            console.error("PDF Export error:", err);
            alert("Erreur lors de la génération du PDF: " + err.message);
        }
    }

    // Initialize
    loadDraft();
})();
