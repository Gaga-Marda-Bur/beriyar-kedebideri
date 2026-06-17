(function () {
    const canvas = document.getElementById("stickerCanvas");
    const ctx = canvas.getContext("2d");
    const textInput = document.getElementById("stickerText");

    let currentStyle = "classic";
    let currentColor = "#D4AF37";
    let currentMode = "photo";

    const beriyaKeyboard = document.getElementById("beriyaMiniKeyboard");
    const openKeyboardBtn = document.getElementById("openBeriyaKeyboard");

    const beriyaChars = [];
    for (let code = 0x16EA0; code <= 0x16EB8; code++) {
        beriyaChars.push(String.fromCodePoint(code));
    }

    const i18n = window.STICKER_I18N || {
        brand: "Beřiyar Kedebideři",
        emptyText: "Écris ton texte",
        space: "Espace",
        clear: "Vider",
        filenameImage: "beriyar-image.png",
        filenameSticker: "beriyar-sticker.png",
    };

    function insertAtCursor(input, value) {
        const start = input.selectionStart ?? input.value.length;
        const end = input.selectionEnd ?? input.value.length;
        input.value = input.value.slice(0, start) + value + input.value.slice(end);
        input.selectionStart = input.selectionEnd = start + value.length;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.focus();
    }

    function buildKeyboard() {
        beriyaKeyboard.innerHTML = "";

        beriyaChars.forEach((char) => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "beriya-mini-key";
            btn.textContent = char;
            btn.addEventListener("click", () => insertAtCursor(textInput, char));
            beriyaKeyboard.appendChild(btn);
        });

        const space = document.createElement("button");
        space.type = "button";
        space.className = "beriya-mini-key wide";
        space.textContent = i18n.space;
        space.addEventListener("click", () => insertAtCursor(textInput, " "));
        beriyaKeyboard.appendChild(space);

        const clear = document.createElement("button");
        clear.type = "button";
        clear.className = "beriya-mini-key wide";
        clear.textContent = i18n.clear;
        clear.addEventListener("click", () => {
            textInput.value = "";
            draw();
        });
        beriyaKeyboard.appendChild(clear);
    }

    function wrapText(ctx, text, maxWidth) {
        const words = text.split(/\s+/);
        const lines = [];
        let line = "";

        words.forEach((word) => {
            const test = line ? line + " " + word : word;
            if (ctx.measureText(test).width > maxWidth && line) {
                lines.push(line);
                line = word;
            } else {
                line = test;
            }
        });

        if (line) lines.push(line);
        return lines;
    }

    function roundedRect(ctx, x, y, width, height, radius) {
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + width - radius, y);
        ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
        ctx.lineTo(x + width, y + height - radius);
        ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
        ctx.lineTo(x + radius, y + height);
        ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
        ctx.lineTo(x, y + radius);
        ctx.quadraticCurveTo(x, y, x + radius, y);
        ctx.closePath();
    }

    function drawBackground() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        if (currentMode === "sticker") {
            return;
        }

        const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);

        if (currentStyle === "child") {
            gradient.addColorStop(0, "#BDEAFE");
            gradient.addColorStop(1, "#FFF4B8");
        } else if (currentStyle === "premium") {
            gradient.addColorStop(0, "#061A14");
            gradient.addColorStop(1, "#1B4D3E");
        } else if (currentStyle === "culture") {
            gradient.addColorStop(0, "#10291F");
            gradient.addColorStop(1, "#D4AF37");
        } else {
            gradient.addColorStop(0, "#0F3227");
            gradient.addColorStop(1, "#071B15");
        }

        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    function drawStickerShape() {
        if (currentMode === "sticker") {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        }

        ctx.save();
        ctx.shadowColor = "rgba(0,0,0,0.28)";
        ctx.shadowBlur = 35;
        ctx.shadowOffsetY = 18;

        roundedRect(ctx, 90, 150, 900, 760, 70);

        if (currentMode === "sticker") {
            ctx.fillStyle = "#FFF7E1";
        } else {
            ctx.fillStyle = "rgba(255,255,255,0.09)";
        }

        ctx.fill();

        ctx.lineWidth = 10;
        ctx.strokeStyle = currentColor;
        ctx.stroke();

        ctx.restore();
    }

    function drawDecorations() {
        ctx.save();

        ctx.fillStyle = currentColor;
        ctx.globalAlpha = 0.9;

        ctx.font = "80px serif";
        ctx.textAlign = "center";
        ctx.fillText("✦", 540, 250);

        ctx.globalAlpha = 0.35;
        ctx.fillText("✧", 220, 360);
        ctx.fillText("✧", 860, 720);

        ctx.restore();
    }

    function drawText() {
        const text = textInput.value.trim() || i18n.emptyText;
        const maxWidth = 760;

        ctx.save();

        if (currentStyle === "calligraphy") {
            ctx.font = "bold 72px Kedebideri, Georgia, serif";
        } else {
            ctx.font = "bold 64px Kedebideri, Arial, sans-serif";
        }

        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillStyle = currentMode === "sticker" ? "#123428" : "#FFFFFF";

        const lines = wrapText(ctx, text, maxWidth);
        const lineHeight = 86;
        const totalHeight = lines.length * lineHeight;
        let y = 540 - totalHeight / 2 + lineHeight / 2;

        lines.forEach((line) => {
            ctx.fillText(line, 540, y);
            y += lineHeight;
        });

        ctx.restore();
    }

    function drawLogoText() {
        ctx.save();
        ctx.font = "bold 28px Arial, sans-serif";
        ctx.textAlign = "center";
        ctx.fillStyle = currentColor;
        ctx.fillText(i18n.brand, 540, 835);
        ctx.restore();
    }

    function draw() {
        drawBackground();
        drawStickerShape();
        drawDecorations();
        drawText();
        drawLogoText();
    }

    function download(filename) {
        const link = document.createElement("a");
        link.download = filename;
        link.href = canvas.toDataURL("image/png");
        link.click();
    }

    document.querySelectorAll(".sticker-style").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".sticker-style").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            currentStyle = btn.dataset.style;
            draw();
        });
    });

    document.querySelectorAll(".color-dot").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".color-dot").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            currentColor = btn.dataset.color;
            draw();
        });
    });

    document.querySelectorAll(".output-mode").forEach((btn) => {
        btn.addEventListener("click", () => {
            document.querySelectorAll(".output-mode").forEach((b) => b.classList.remove("active"));
            btn.classList.add("active");
            currentMode = btn.dataset.mode;
            draw();
        });
    });

    textInput.addEventListener("input", draw);

    document.getElementById("downloadPng").addEventListener("click", () => {
        download(i18n.filenameImage);
    });

    document.getElementById("downloadSticker").addEventListener("click", () => {
        currentMode = "sticker";
        document.querySelectorAll(".output-mode").forEach((b) => b.classList.remove("active"));
        document.querySelector("[data-mode='sticker']").classList.add("active");
        draw();
        download(i18n.filenameSticker);
    });

    openKeyboardBtn.addEventListener("click", () => {
        beriyaKeyboard.hidden = !beriyaKeyboard.hidden;
    });

    buildKeyboard();

    if (document.fonts) {
        document.fonts.ready.then(function () {
            draw();
        });
    } else {
        draw();
    }
})();