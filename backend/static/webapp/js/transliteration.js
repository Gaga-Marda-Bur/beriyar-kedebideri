(function (g) {
    'use strict';
    const data = typeof module !== 'undefined' ? require('./transliteration_data.js') : g.BKTransliterationData;
    const rows = data.rows, scripts = ['erfe', 'latin', 'arabic'];
    const aliases = new Map(rows.map(r => [r[1], r[0]]));
    const sources = {
        erfe: new Map(rows.map(r => [r[0], r[0]])),
        latin: new Map(rows.flatMap(r => [[r[2], r[0]], [r[3], r[0]]])),
        arabic: new Map(rows.map(r => [r[4], r[0]]))
    };
    function normalize_erfe(text) {
        return Array.from(text, c => aliases.get(c) || c).join('').normalize('NFC');
    }
    function transliterate(text, source, target, latinLowercase = false) {
        if (!scripts.includes(source) || !scripts.includes(target)) throw new Error('Invalid script');
        const column = {erfe: 0, latin: latinLowercase ? 3 : 2, arabic: 4}[target];
        const out = new Map(rows.map(r => [r[0], r[column]])), unmapped = [];
        const result = Array.from(normalize_erfe(text), (c, index) => {
            const canonical = sources[source].get(c);
            if (canonical !== undefined) return out.get(canonical);
            const cp = c.codePointAt(0);
            if (!data.passthrough_ranges.some(([a, b]) => a <= cp && cp <= b)) {
                unmapped.push({character: c, codepoint: 'U+' + cp.toString(16).toUpperCase().padStart(4, '0'), index});
            }
            return c;
        }).join('').normalize('NFC');
        return {text: result, unmapped};
    }
    const api = {normalize_erfe, transliterate};
    if (typeof module !== 'undefined') module.exports = api;
    else g.BKTransliteration = api;
})(globalThis);
