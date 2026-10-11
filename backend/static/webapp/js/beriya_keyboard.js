(function () {
    const data = window.BERIYA_KEYBOARD_DATA;

    const i18n = window.BERIYA_KEYBOARD_I18N || {
        title: "Clavier Beriya Erfe",
        toggle: "⌨️ Clavier Beriya",
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
    let lastSelectionStart = 0;
    let lastSelectionEnd = 0;
    let currentLayout = "fast";
    let showSymbols = false;
    let wrapper = null;
    let keysContainer = null;
    let longPressTimer = null;
    let longPressTriggered = false;
    let activePopup = null;

    function saveSelection(input) {
        if (!input || input.isContentEditable) return;

        if (
            typeof input.selectionStart === "number" &&
            typeof input.selectionEnd === "number"
        ) {
            lastSelectionStart = input.selectionStart;
            lastSelectionEnd = input.selectionEnd;
        }
    }

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
        const isTextField =
            tag === "textarea" ||
            tag === "input" ||
            element.isContentEditable;

        if (!isTextField) return false;

        return element.dataset.beriyaKeyboard === "true";
    }

    function rememberActiveInput(event) {
        const target = event.target;

        if (isWritableElement(target)) {
            activeInput = target;
            saveSelection(activeInput);
        }
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

        if (activeInput.isContentEditable) {
            activeInput.focus({ preventScroll: true });
            document.execCommand("insertText", false, text);
            return;
        }

        activeInput.focus({ preventScroll: true });

        let start = typeof activeInput.selectionStart === "number"
            ? activeInput.selectionStart
            : lastSelectionStart;

        let end = typeof activeInput.selectionEnd === "number"
            ? activeInput.selectionEnd
            : lastSelectionEnd;

        if (start === 0 && end === 0 && activeInput.value.length > 0) {
            start = lastSelectionStart || activeInput.value.length;
            end = lastSelectionEnd || activeInput.value.length;
        }

        activeInput.value =
            activeInput.value.substring(0, start) +
            text +
            activeInput.value.substring(end);

        const newPosition = start + text.length;
        activeInput.setSelectionRange(newPosition, newPosition);
        lastSelectionStart = newPosition;
        lastSelectionEnd = newPosition;

        activeInput.dispatchEvent(new Event("input", { bubbles: true }));
        activeInput.dispatchEvent(new Event("change", { bubbles: true }));
    }

    function getGraphemeDeleteRange(val, start) {
        if (!val || start <= 0) return { from: 0, to: 0 };

        if (typeof Intl !== "undefined" && Intl.Segmenter) {
            try {
                const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
                const segments = Array.from(segmenter.segment(val));
                for (let i = segments.length - 1; i >= 0; i--) {
                    const seg = segments[i];
                    const segStart = seg.index;
                    const segEnd = seg.index + seg.segment.length;
                    if (segEnd <= start) {
                        return { from: segStart, to: start };
                    }
                    if (start > segStart && start < segEnd) {
                        return { from: segStart, to: segEnd };
                    }
                }
            } catch (_) {}
        }

        // Fallback for surrogate pairs (SMP Unicode U+10000..U+10FFFF)
        let from = Math.max(0, start - 1);
        if (from > 0) {
            const prev = val.charCodeAt(from);
            const prevPrev = val.charCodeAt(from - 1);
            if (prev >= 0xDC00 && prev <= 0xDFFF && prevPrev >= 0xD800 && prevPrev <= 0xDBFF) {
                from = from - 1;
            }
        }
        return { from, to: start };
    }

    function backspace() {
        if (!activeInput || activeInput.isContentEditable) return;

        activeInput.focus({ preventScroll: true });

        let start = typeof activeInput.selectionStart === "number"
            ? activeInput.selectionStart
            : lastSelectionStart;
        let end = typeof activeInput.selectionEnd === "number"
            ? activeInput.selectionEnd
            : lastSelectionEnd;

        if (start === 0 && end === 0 && activeInput.value.length > 0 && lastSelectionStart > 0) {
            start = lastSelectionStart;
            end = lastSelectionEnd;
        }

        if (start !== end) {
            activeInput.value =
                activeInput.value.substring(0, start) +
                activeInput.value.substring(end);
            activeInput.setSelectionRange(start, start);
            lastSelectionStart = start;
            lastSelectionEnd = start;
        } else if (start > 0) {
            const range = getGraphemeDeleteRange(activeInput.value, start);
            activeInput.value =
                activeInput.value.substring(0, range.from) +
                activeInput.value.substring(range.to);
            activeInput.setSelectionRange(range.from, range.from);
            lastSelectionStart = range.from;
            lastSelectionEnd = range.from;
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

        button.addEventListener("pointerdown", (event) => {
            event.preventDefault();

            if (activeInput) {
                saveSelection(activeInput);
            }
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

    let historyStatePushed = false;

    function hasWritableInputOnPage() {
        return document.querySelector("[data-beriya-keyboard='true'], textarea, input:not([type='hidden']):not([type='submit']):not([type='checkbox']):not([type='radio'])") !== null;
    }

    function createKeyboard() {
        if (wrapper) return;

        wrapper = document.createElement("div");
        wrapper.className = "beriya-keyboard";
        wrapper.innerHTML = `
            <button type="button" class="beriya-keyboard-toggle" aria-label="${i18n.title}">
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

        let userDismissed = false;

        // Single controller object
        window.BeriyaKeyboard = {
            open: function (targetInput) {
                userDismissed = false;
                if (targetInput) {
                    activeInput = targetInput;
                    saveSelection(activeInput);
                } else if (!activeInput) {
                    const fallback = document.querySelector("[data-beriya-keyboard='true']") || document.querySelector("textarea, input[type='text']");
                    if (fallback) {
                        activeInput = fallback;
                        saveSelection(activeInput);
                    }
                }

                wrapper.style.display = "block";
                panel.hidden = false;
                toggle.style.display = "none";
                toggle.classList.add("active");
                renderKeys();

                try {
                    if (!historyStatePushed) {
                        history.pushState({ beriyaKeyboardOpen: true }, "");
                        historyStatePushed = true;
                    }
                } catch (_) {}
            },

            close: function (fromHistory) {
                panel.hidden = true;
                removePopup();
                toggle.classList.remove("active");

                if (document.querySelector(".beriya-editor-page") || document.getElementById("beriyaMiniKeyboard") || !hasWritableInputOnPage()) {
                    wrapper.style.display = "none";
                    toggle.style.display = "none";
                } else {
                    wrapper.style.display = "block";
                    toggle.style.display = "inline-flex";
                }

                if (historyStatePushed && fromHistory !== true) {
                    historyStatePushed = false;
                    try {
                        if (history.state && history.state.beriyaKeyboardOpen) {
                            history.back();
                        }
                    } catch (_) {}
                }
            },

            toggle: function () {
                if (panel.hidden || wrapper.style.display === "none") {
                    window.BeriyaKeyboard.open();
                } else {
                    window.BeriyaKeyboard.close();
                }
            },

            showTriggerOnly: function () {
                // If keyboard panel is already open, NEVER close it!
                if (panel && !panel.hidden) return;

                if (document.getElementById("beriyaMiniKeyboard")) return;
                if (document.querySelector(".beriya-editor-page")) return;

                if (hasWritableInputOnPage()) {
                    wrapper.style.display = "block";
                    toggle.style.display = "inline-flex";
                    panel.hidden = true;
                }
            }
        };

        // Initialize visibility on page load
        if (hasWritableInputOnPage() && !document.querySelector(".beriya-editor-page") && !document.getElementById("beriyaMiniKeyboard")) {
            wrapper.style.display = "block";
            toggle.style.display = "inline-flex";
            panel.hidden = true;
        } else {
            wrapper.style.display = "none";
            toggle.style.display = "none";
            panel.hidden = true;
        }

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
            window.BeriyaKeyboard.toggle();
        });

        close.addEventListener("click", () => {
            window.BeriyaKeyboard.close();
        });

        // Android back / history handling
        window.addEventListener("popstate", (event) => {
            if (panel && !panel.hidden) {
                historyStatePushed = false;
                window.BeriyaKeyboard.close(true);
            }
        });

        // Escape key handling
        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape" && panel && !panel.hidden) {
                window.BeriyaKeyboard.close();
            }

            // Intercept physical Backspace on Beriya inputs to guarantee atomic deletion of surrogate pairs & combining marks
            if (event.key === "Backspace" && !event.ctrlKey && !event.altKey && !event.metaKey) {
                const target = event.target;
                if (isWritableElement(target) && target.value) {
                    rememberActiveInput(event);
                    event.preventDefault();
                    backspace();
                }
            }
        });

        attachKeyEvents(wrapper.querySelector("[data-action='dot']"), ".");

        wrapper.querySelector("[data-action='space']").addEventListener("pointerdown", (event) => {
            event.preventDefault();
        });

        wrapper.querySelector("[data-action='space']").addEventListener("click", (event) => {
            event.preventDefault();
            insertText(" ");
        });

        wrapper.querySelector("[data-action='backspace']").addEventListener("pointerdown", (event) => {
            event.preventDefault();
        });

        wrapper.querySelector("[data-action='backspace']").addEventListener("click", (event) => {
            event.preventDefault();
            backspace();
        });

        wrapper.querySelector("[data-action='clear']").addEventListener("pointerdown", (event) => {
            event.preventDefault();
        });

        wrapper.querySelector("[data-action='clear']").addEventListener("click", (event) => {
            event.preventDefault();
            clearInput();
        });

        document.addEventListener("click", (event) => {
            if (activePopup && !activePopup.contains(event.target)) {
                removePopup();
            }
        });

        renderKeys();
    }

    document.addEventListener("focusin", (event) => {
        rememberActiveInput(event);
        if (isWritableElement(event.target) && window.BeriyaKeyboard) {
            window.BeriyaKeyboard.showTriggerOnly();
        }
    });

    document.addEventListener("click", rememberActiveInput);

    function initKeyboard() {
        if (document.fonts) {
            document.fonts.ready.then(createKeyboard);
        } else {
            createKeyboard();
        }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initKeyboard);
    } else {
        initKeyboard();
    }
})();