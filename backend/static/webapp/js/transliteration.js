(function (g) {
    'use strict';
    const data = typeof module !== 'undefined' ? require('./transliteration_data.js') : g.BKTransliterationData;
    const rows = data.rows, scripts = ['erfe', 'latin', 'arabic'];
    const aliases = new Map(rows.filter(r => Array.from(r[1]).length === 1).map(r => [r[1], r[0]]));
    const sources = {
        erfe: new Map(rows.map(r => [r[0], r[0]])),
        latin: new Map(rows.flatMap(r => [[r[2], r[0]], [r[3], r[0]]])),
        arabic: new Map(rows.filter(r => r[4] !== null).map(r => [r[4], r[0]]))
    };
    function normalize_erfe(text) {
        return Array.from(text, c => aliases.get(c) || c).join('').normalize('NFC');
    }
    function transliterate(text, source, target, latinLowercase = false) {
        if (!scripts.includes(source) || !scripts.includes(target)) throw new Error('Invalid script');
        const column = {erfe: 0, latin: latinLowercase ? 3 : 2, arabic: 4}[target];
        const out = new Map(rows.map(r => [r[0], r[column]])), unmapped = [];
        const chars = Array.from(normalize_erfe(text)), result = [];
        const inRanges = (cp, ranges) => ranges.some(([a, b]) => a <= cp && cp <= b);
        for (let index = 0; index < chars.length;) {
            let end = index + 1;
            while (end < chars.length && inRanges(chars[end].codePointAt(0), data.combining_ranges)) end++;
            const unit = chars.slice(index, end).join('');
            const canonical = sources[source].get(unit), mapped = out.get(canonical);
            if (mapped != null) result.push(mapped);
            else {
                result.push(unit);
                if (end - index !== 1 || !inRanges(unit.codePointAt(0), data.passthrough_ranges)) {
                    const item = {character: unit, codepoint: Array.from(unit, c => 'U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')).join(' '), index};
                    if (canonical !== undefined && target === 'arabic') item.reason = 'missing_arabic_mapping';
                    unmapped.push(item);
                }
            }
            index = end;
        }
        return {text: result.join('').normalize('NFC'), unmapped};
    }
    const api = {normalize_erfe, transliterate};
    if (typeof module !== 'undefined') module.exports = api;
    else g.BKTransliteration = api;
})(globalThis);
