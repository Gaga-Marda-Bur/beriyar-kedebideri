(function () {
    const data = window.BERIYA_KEYBOARD_DATA;

    const i18n = window.BERIYA_KEYBOARD_I18N || {
        title: "Clavier Beriya Erfe",
        toggle: "𖺠 Clavier",
        close: "×",
        fast: "Rapide",
        abc: "ABC",
        symbols: ".?123",
        space: "Espace",
        backspace: "Effacer",
        clear: "Vider",
        clickInputFirst: "Clique d’abord dans un champ de texte."
    };

    let activeInput = null;
    let currentLayout = "fast";
    let showSymbols = false;
    let wrapper = null;
    let keysContainer = null;
    let longPressTimer = null;
    let longPressTriggered = false;
    let activePopup = null;

    function rowsForMode() {
        if (showSymbols) return data.symbolRows;
        return currentLayout === "fast" ? data.fastRows : data.learningRows;
    }

    function isBeriyaMode() {
        return !showSymbols;
    }

    function isWritableElement(element) {
        if (!element) return false;
        const tag = element.tagName ? element.tagName.toLowerCase() : "";
        return tag === "textarea" || tag === "input" || element.isContentEditable;
    }

    function rememberActiveInput(event) {
        const target = event.target;
        if (isWritableElement(target)) activeInput = target;
    }

    function insertText(text) {
        if (!activeInput) {
            const possibleInput = document.querySelector("[data-beriya-keyboard='true']");
            if (possibleInput) {
                activeInput = possibleInput;
                activeInput.focus();
            }
        }

        if (!activeInput) {
            alert(i18n.clickInputFirst);
            return;
        }

        activeInput.focus();

        if (activeInput.isContentEditable) {
            document.execCommand("insertText", false, text);
            return;
        }

        const start = activeInput.selectionStart ?? activeInput.value.length;
        const end = activeInput.selectionEnd ?? activeInput.value.length;

        activeInput.value =
            activeInput.value.substring(0, start) +
            text +
            activeInput.value.substring(end);

        const newPosition = start + text.length;
        activeInput.setSelectionRange(newPosition, newPosition);

        activeInput.dispatchEvent(new Event("input", { bubbles: true }));
        activeInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    function backspace() {
        if (!activeInput || activeInput.isContentEditable) return;

        activeInput.focus();

        const start = activeInput.selectionStart ?? activeInput.value.length;
        const end = activeInput.selectionEnd ?? activeInput.value.length;

        if (start !== end) {
            activeInput.value =
                activeInput.value.substring(0, start) +
                activeInput.value.substring(end);
            activeInput.setSelectionRange(start, start);
        } else if (start > 0) {
            activeInput.value =
                activeInput.value.substring(0, start - 1) +
                activeInput.value.substring(start);
            activeInput.setSelectionRange(start - 1, start - 1);
        }

        activeInput.dispatchEvent(new Event("input", { bubbles: true }));
        activeInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    function clearInput() {
        if (!activeInput || activeInput.isContentEditable) return;

        activeInput.focus();
        activeInput.value = "";
        activeInput.dispatchEvent(new Event("input", { bubbles: true }));
        activeInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    function removePopup() {
        if (activePopup) {
            activePopup.remove();
            activePopup = null;
        }
    }

    function showLongPressMenu(button, options) {
        removePopup();

        const rect = button.getBoundingClientRect();

        const popup = document.createElement("div");
        popup.className = "beriya-longpress-popup";

        options.forEach((option) => {
            const opt = document.createElement("button");
            opt.type = "button";
            opt.className = hasBeriya(option) ? "beriya-font" : "";
            opt.textContent = option;
            opt.addEventListener("click", (event) => {
                event.preventDefault();
                event.stopPropagation();
                insertText(option);
                removePopup();
            });
            popup.appendChild(opt);
        });

        popup.style.left = `${Math.max(8, rect.left)}px`;
        popup.style.top = `${Math.max(8, rect.top - 58)}px`;

        document.body.appendChild(popup);
        activePopup = popup;
    }

    function hasBeriya(text) {
        return Array.from(text).some((char) => {
            const code = char.codePointAt(0);
            return code >= 0x16EA0 && code <= 0x16EB8;
        });
    }

    function attachKeyEvents(button, value) {
        const options = data.longPressOptions[value];

        button.addEventListener("pointerdown", () => {
            longPressTriggered = false;
            if (!options || options.length === 0) return;

            longPressTimer = window.setTimeout(() => {
                longPressTriggered = true;
                showLongPressMenu(button, options);
            }, 450);
        });

        button.addEventListener("pointerup", () => {
            if (longPressTimer) {
                window.clearTimeout(longPressTimer);
                longPressTimer = null;
            }
        });

        button.addEventListener("pointerleave", () => {
            if (longPressTimer) {
                window.clearTimeout(longPressTimer);
                longPressTimer = null;
            }
        });

        button.addEventListener("click", (event) => {
            if (longPressTriggered) {
                event.preventDefault();
                event.stopPropagation();
                longPressTriggered = false;
                return;
            }

            insertText(value);
        });
    }

    function renderModeButtons() {
        wrapper.querySelectorAll("[data-keyboard-layout]").forEach((button) => {
            button.classList.toggle("active", button.dataset.keyboardLayout === currentLayout && !showSymbols);
        });

        const symbolButton = wrapper.querySelector("[data-keyboard-symbols]");
        if (symbolButton) symbolButton.classList.toggle("active", showSymbols);
    }

    function renderKeys() {
        keysContainer.innerHTML = "";

        rowsForMode().forEach((row, rowIndex) => {
            const rowEl = document.createElement("div");
            rowEl.className = `beriya-keyboard-row row-${rowIndex + 1}`;

            row.forEach((char) => {
                const button = document.createElement("button");
                button.type = "button";
                button.className = isBeriyaMode()
                    ? "beriya-key beriya-font"
                    : "beriya-key";
                button.textContent = char;

                attachKeyEvents(button, char);

                rowEl.appendChild(button);
            });

            keysContainer.appendChild(rowEl);
        });

        renderModeButtons();
    }

    function createKeyboard() {
        wrapper = document.createElement("div");
        wrapper.className = "beriya-keyboard";
        wrapper.innerHTML = `
            <button type="button" class="beriya-keyboard-toggle beriya-font" aria-label="${i18n.title}">
                ${i18n.toggle}
            </button>

            <div class="beriya-keyboard-panel" hidden>
                <div class="beriya-keyboard-header">
                    <strong>${i18n.title}</strong>
                    <button type="button" class="beriya-keyboard-close" aria-label="${i18n.close}">${i18n.close}</button>
                </div>

                <div class="beriya-keyboard-modes">
                    <button type="button" data-keyboard-layout="fast" class="active">${i18n.fast}</button>
                    <button type="button" data-keyboard-layout="abc">${i18n.abc}</button>
                    <button type="button" data-keyboard-symbols>${i18n.symbols}</button>
                </div>

                <div class="beriya-keyboard-keys"></div>

                <div class="beriya-keyboard-actions">
                    <button type="button" data-action="dot">.</button>
                    <button type="button" data-action="space">${i18n.space}</button>
                    <button type="button" data-action="backspace">⌫</button>
                    <button type="button" data-action="clear">${i18n.clear}</button>
                </div>
            </div>
        `;

        document.body.appendChild(wrapper);

        const toggle = wrapper.querySelector(".beriya-keyboard-toggle");
        const panel = wrapper.querySelector(".beriya-keyboard-panel");
        const close = wrapper.querySelector(".beriya-keyboard-close");
        keysContainer = wrapper.querySelector(".beriya-keyboard-keys");

        wrapper.querySelector("[data-keyboard-layout='fast']").addEventListener("click", () => {
            currentLayout = "fast";
            showSymbols = false;
            renderKeys();
        });

        wrapper.querySelector("[data-keyboard-layout='abc']").addEventListener("click", () => {
            currentLayout = "abc";
            showSymbols = false;
            renderKeys();
        });

        wrapper.querySelector("[data-keyboard-symbols]").addEventListener("click", () => {
            showSymbols = true;
            renderKeys();
        });

        toggle.addEventListener("click", () => {
            panel.hidden = !panel.hidden;
        });

        close.addEventListener("click", () => {
            panel.hidden = true;
            removePopup();
        });

        attachKeyEvents(wrapper.querySelector("[data-action='dot']"), ".");

        wrapper.querySelector("[data-action='space']").addEventListener("click", () => {
            insertText(" ");
        });

        wrapper.querySelector("[data-action='backspace']").addEventListener("click", () => {
            backspace();
        });

        wrapper.querySelector("[data-action='clear']").addEventListener("click", () => {
            clearInput();
        });

        document.addEventListener("click", (event) => {
            if (activePopup && !activePopup.contains(event.target)) {
                removePopup();
            }
        });

        renderKeys();
    }

    document.addEventListener("focusin", rememberActiveInput);
    document.addEventListener("click", rememberActiveInput);

    document.addEventListener("DOMContentLoaded", function () {
        if (document.fonts) {
            document.fonts.ready.then(createKeyboard);
        } else {
            createKeyboard();
        }
    });
})();