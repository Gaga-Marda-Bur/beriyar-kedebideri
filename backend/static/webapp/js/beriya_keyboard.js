(function () {
    const BERIA_START = 0x16EA0;
    const BERIA_END = 0x16EB8;

    const characters = [];
    for (let code = BERIA_START; code <= BERIA_END; code++) {
        characters.push(String.fromCodePoint(code));
    }

    let activeInput = null;

    function isWritableElement(element) {
        if (!element) return false;

        const tag = element.tagName ? element.tagName.toLowerCase() : "";

        return (
            tag === "textarea" ||
            tag === "input" ||
            element.isContentEditable
        );
    }

    function rememberActiveInput(event) {
        const target = event.target;

        if (isWritableElement(target)) {
            activeInput = target;
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
            alert("Clique d’abord dans un champ de texte.");
            return;
        }

        activeInput.focus();

        if (activeInput.isContentEditable) {
            document.execCommand("insertText", false, text);
            return;
        }

        const start = activeInput.selectionStart ?? activeInput.value.length;
        const end = activeInput.selectionEnd ?? activeInput.value.length;

        const before = activeInput.value.substring(0, start);
        const after = activeInput.value.substring(end);

        activeInput.value = before + text + after;

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

    function createKeyboard() {
        const wrapper = document.createElement("div");
        wrapper.className = "beriya-keyboard";
        wrapper.innerHTML = `
            <button type="button" class="beriya-keyboard-toggle" aria-label="Clavier Beriya">
                𖺠 Clavier
            </button>

            <div class="beriya-keyboard-panel" hidden>
                <div class="beriya-keyboard-header">
                    <strong>Clavier Beriya Erfe</strong>
                    <button type="button" class="beriya-keyboard-close" aria-label="Fermer">×</button>
                </div>

                <div class="beriya-keyboard-keys"></div>

                <div class="beriya-keyboard-actions">
                    <button type="button" data-action="space">Espace</button>
                    <button type="button" data-action="backspace">Effacer</button>
                    <button type="button" data-action="clear">Vider</button>
                </div>
            </div>
        `;

        document.body.appendChild(wrapper);

        const toggle = wrapper.querySelector(".beriya-keyboard-toggle");
        const panel = wrapper.querySelector(".beriya-keyboard-panel");
        const close = wrapper.querySelector(".beriya-keyboard-close");
        const keysContainer = wrapper.querySelector(".beriya-keyboard-keys");

        characters.forEach((char, index) => {
            const button = document.createElement("button");
            button.type = "button";
            button.className = "beriya-key";
            button.textContent = char;
            button.title = `U+${(BERIA_START + index).toString(16).toUpperCase()}`;
            button.addEventListener("click", () => insertText(char));
            keysContainer.appendChild(button);
        });

        toggle.addEventListener("click", () => {
            panel.hidden = !panel.hidden;
        });

        close.addEventListener("click", () => {
            panel.hidden = true;
        });

        wrapper.querySelector("[data-action='space']").addEventListener("click", () => {
            insertText(" ");
        });

        wrapper.querySelector("[data-action='backspace']").addEventListener("click", () => {
            backspace();
        });

        wrapper.querySelector("[data-action='clear']").addEventListener("click", () => {
            clearInput();
        });
    }

    document.addEventListener("focusin", rememberActiveInput);
    document.addEventListener("click", rememberActiveInput);

    document.addEventListener("DOMContentLoaded", createKeyboard);
})();