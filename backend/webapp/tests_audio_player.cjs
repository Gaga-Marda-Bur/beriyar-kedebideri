const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const script = fs.readFileSync(path.resolve(__dirname, '../static/webapp/js/audio_player.js'), 'utf8');

function fixture() {
    class Element {
        constructor(text = '') { this.textContent = text; this.dataset = {}; this.listeners = {}; this.attrs = {}; }
        addEventListener(name, callback) { (this.listeners[name] ??= []).push(callback); }
        async emit(name, event = {}) {
            await Promise.all((this.listeners[name] ?? []).map(fn => fn({target: this, ...event})));
        }
        setAttribute(name, value) { this.attrs[name] = value; }
        after(element) { this.afterElement = element; }
    }
    let document;
    class Audio extends Element {
        constructor() { super(); this.paused = true; this.fail = false; this.stops = 0; }
        async play() {
            if (this.fail) throw new Error('unavailable');
            this.paused = false;
            await document.emit('play', {target: this});
            await this.emit('playing');
        }
        pause() {
            this.stops++;
            if (!this.paused) { this.paused = true; void this.emit('pause'); }
        }
    }
    const buttons = [new Element('Écouter A'), new Element('Écouter B')];
    buttons[0].dataset.audio = '/audio/a.mp3';
    buttons[1].dataset.audio = '/audio/b.mp3';
    const native = new Audio();
    const audios = [native];
    document = new Element();
    document.documentElement = {lang: 'fr'};
    document.body = {appendChild: element => audios.push(element)};
    document.createElement = name => name === 'audio' ? new Audio() : new Element();
    document.querySelectorAll = selector => selector === '[data-audio]' ? buttons :
        selector === 'audio.quiz-audio' ? [native] : audios;
    vm.runInNewContext(script, {document, window: new Element()});
    return {buttons, native, player: audios[1]};
}

test('buttons expose playing and paused states and retain accessible labels', async () => {
    const {buttons, player} = fixture();
    await buttons[0].emit('click');
    assert.equal(player.src, '/audio/a.mp3');
    assert.equal(buttons[0].textContent, 'Pause');
    assert.equal(buttons[0].attrs['aria-pressed'], 'true');
    await buttons[0].emit('click');
    assert.equal(buttons[0].textContent, 'Écouter A');
    assert.equal(buttons[0].attrs['aria-pressed'], 'false');
});
test('failed audio displays retry and can recover', async () => {
    const {buttons, player} = fixture();
    player.fail = true;
    await buttons[0].emit('click');
    assert.equal(buttons[0].textContent, 'Réessayer');
    assert.match(buttons[0].afterElement.textContent, /indisponible/);
    player.fail = false;
    await buttons[0].emit('click');
    assert.equal(buttons[0].textContent, 'Pause');
    assert.equal(buttons[0].afterElement.textContent, '');
});
test('switching buttons and native quiz playback never overlaps voices', async () => {
    const {buttons, player, native} = fixture();
    await buttons[0].emit('click');
    await buttons[1].emit('click');
    assert.equal(buttons[0].textContent, 'Écouter A');
    assert.equal(player.src, '/audio/b.mp3');
    assert.ok(native.stops > 0);
    await native.play();
    assert.equal(player.paused, true);
    assert.equal(buttons[1].attrs['aria-pressed'], 'false');
});
