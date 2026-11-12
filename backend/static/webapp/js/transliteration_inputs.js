(function () {
    'use strict';
    const api = window.BKTransliteration;
    if (!api) return;
    const selector = '[data-beriya-keyboard="true"], [data-erfe-input], #id_beriya_text, #id_latin_transcription, #id_arabic_transcription, #id_symbol';
    const writable = el => el && el.matches && el.matches(selector) && !el.readOnly && !el.disabled && !el.isContentEditable;
    let repairing = false;
    function canonicalize(el) {
        const before = el.value, after = api.normalize_erfe(before);
        if (before === after) return;
        const start = el.selectionStart, end = el.selectionEnd, direction = el.selectionDirection;
        el.value = after;
        if (start !== null) el.setSelectionRange(api.normalize_erfe(before.slice(0, start)).length,
            api.normalize_erfe(before.slice(0, end)).length, direction);
    }
    // Intercept typing/paste before insertion so the browser owns the undo transaction.
    document.addEventListener('beforeinput', event => {
        if (repairing || event.isComposing || !writable(event.target) || !event.cancelable) return;
        const text = event.dataTransfer ? event.dataTransfer.getData('text/plain') : event.data;
        if (text == null || api.normalize_erfe(text) === text) return;
        event.preventDefault();
        repairing = true;
        const el = event.target;
        const canonical = api.normalize_erfe(text);
        if (!document.execCommand('insertText', false, canonical)) {
            el.setRangeText(canonical, el.selectionStart, el.selectionEnd, 'end');
            el.dispatchEvent(new Event('input', {bubbles: true}));
        }
        repairing = false;
    }, true);
    document.addEventListener('input', event => {
        if (!event.isComposing && writable(event.target)) canonicalize(event.target);
    }, true);
    document.addEventListener('compositionend', event => {
        if (writable(event.target)) canonicalize(event.target);
    }, true);
    function attach() {
        document.querySelectorAll(selector).forEach(el => {
            if (!writable(el) || el.dataset.erfeToolsAttached) return;
            el.dataset.erfeToolsAttached = 'true';
            const details = document.createElement('details');
            details.className = 'bk-transliteration';
            const summary = document.createElement('summary'); summary.textContent = 'Erfe | Latin | Arabe'; details.append(summary);
            const panel = document.createElement('fieldset');
            const legend = document.createElement('legend'); legend.textContent = 'Erfe ↔ Latin ↔ Arabe'; panel.append(legend);
            const source = document.createElement('select'), target = document.createElement('select');
            [[source, 'Écriture source'], [target, 'Écriture cible']].forEach(([select, label]) => {
                select.setAttribute('aria-label', label);
                [['erfe', 'Erfe'], ['latin', 'Latin'], ['arabic', 'Arabe']].forEach(([value, name]) => select.add(new Option(name, value)));
            });
            source.value = el.id.includes('latin') ? 'latin' : el.id.includes('arabic') ? 'arabic' : 'erfe';
            target.value = source.value === 'erfe' ? 'latin' : 'erfe';
            const lower = document.createElement('input'); lower.type = 'checkbox';
            const lowerLabel = document.createElement('label'); lowerLabel.append(lower, ' Latin en minuscules');
            const output = document.createElement('textarea');
            output.readOnly = true; output.rows = 2; output.style.width = '100%';
            output.className = 'beriya-font'; output.setAttribute('aria-label', 'Résultat de conversion');
            const status = document.createElement('span'); status.setAttribute('role', 'status');
            function button(label, action) {
                const b = document.createElement('button'); b.type = 'button'; b.textContent = label; b.addEventListener('click', action); return b;
            }
            let snapshot = null, range = null, conversionNotice = '';
            const convert = button('Convertir', () => {
                range = [el.selectionStart, el.selectionEnd]; snapshot = el.value;
                const text = range[0] !== range[1] ? el.value.slice(...range) : el.value;
                const result = api.transliterate(text, source.value, target.value, lower.checked);
                output.value = result.text; output.dir = target.value === 'arabic' ? 'rtl' : 'ltr';
                const missingArabic = result.unmapped.some(c => c.reason === 'missing_arabic_mapping');
                conversionNotice = result.unmapped.length ? 'Conversion incomplète — ' +
                    (missingArabic ? 'correspondances arabes non définies ; ' : '') +
                    'formes conservées : ' + result.unmapped.map(c => c.codepoint).join(', ') : '';
                status.textContent = conversionNotice;
            });
            const apply = button('Insérer', () => {
                if (snapshot === null || el.value !== snapshot) return;
                el.focus();
                if (range[0] === range[1]) el.select(); else el.setSelectionRange(...range);
                const previous = el.value;
                if (!document.execCommand('insertText', false, output.value)) {
                    el.setRangeText(output.value, el.selectionStart, el.selectionEnd, 'end');
                    el.dispatchEvent(new Event('input', {bubbles:true}));
                }
                el.dir = target.value === 'arabic' ? 'rtl' : 'auto';
                // Explicit fallback undo is also available when execCommand is unsupported.
                const insertedValue = el.value, previousRange = [...range];
                undo.onclick = () => {
                    if (el.value !== insertedValue) { status.textContent = 'Texte modifié depuis la conversion : utilisez l’annulation de l’éditeur.'; return; }
                    el.value = previous; el.setSelectionRange(...previousRange); el.dispatchEvent(new Event('input', {bubbles:true}));
                };
                snapshot = null;
            });
            const undo = button('Annuler la conversion', () => {});
            const copy = button('Copier', async () => {
                try { await navigator.clipboard.writeText(output.value); status.textContent = 'Copié. ' + conversionNotice; }
                catch (_) { output.focus(); output.select(); status.textContent = 'Sélectionnez le résultat puis copiez-le. ' + conversionNotice; }
            });
            const invalidate = () => {snapshot = null; output.value = ''; conversionNotice = ''; status.textContent = '';};
            source.addEventListener('change', invalidate); target.addEventListener('change', invalidate); lower.addEventListener('change', invalidate);
            panel.append(source, target, lowerLabel, convert, output, copy, apply, undo, status);
            details.append(panel);
            el.insertAdjacentElement('afterend', details);
        });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', attach); else attach();
})();
