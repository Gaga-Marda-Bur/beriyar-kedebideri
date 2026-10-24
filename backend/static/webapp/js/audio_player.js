// One controller for public audio buttons and native quiz players.
(() => {
    const messages = {
        fr: {loading: 'Chargement…', pause: 'Pause', retry: 'Réessayer', error: 'Audio indisponible. Réessaie.'},
        en: {loading: 'Loading…', pause: 'Pause', retry: 'Try again', error: 'Audio unavailable. Try again.'},
        ar: {loading: 'جارٍ التحميل…', pause: 'إيقاف مؤقت', retry: 'حاول مجددًا', error: 'الصوت غير متاح. حاول مجددًا.'}
    };
    const t = messages[document.documentElement.lang] || messages.fr;
    const player = document.createElement('audio');
    player.preload = 'none';
    document.body.appendChild(player);
    const status = document.createElement('p');
    status.setAttribute('role', 'status');
    status.setAttribute('aria-live', 'polite');
    status.className = 'audio-status';
    let active = null;
    let generation = 0;
    function state(value) {
        if (!active) return;
        active.dataset.audioState = value;
        active.setAttribute('aria-pressed', String(value === 'playing'));
        active.setAttribute('aria-busy', String(value === 'loading'));
        active.textContent = value === 'loading' ? t.loading : value === 'playing' ? t.pause :
            value === 'error' ? t.retry : active.dataset.audioLabel;
    }
    function failure() {
        state('error');
        status.textContent = t.error;
    }
    player.addEventListener('playing', () => state('playing'));
    player.addEventListener('pause', () => state('paused'));
    player.addEventListener('ended', () => state('idle'));
    player.addEventListener('error', failure);
    document.querySelectorAll('[data-audio]').forEach(button => {
        button.dataset.audioLabel = button.textContent.trim();
        button.setAttribute('aria-pressed', 'false');
        button.addEventListener('click', async () => {
            if (active === button && (!player.paused || button.dataset.audioState === 'loading')) {
                generation++;
                player.pause();
                state('paused');
                return;
            }
            const token = ++generation;
            player.pause();
            if (active !== button) {
                state('idle');
                active = button;
                player.src = button.dataset.audio;
            }
            button.after(status);
            status.textContent = '';
            state('loading');
            try { await player.play(); }
            catch (_) { if (token === generation) failure(); }
        });
    });
    document.addEventListener('play', event => {
        document.querySelectorAll('audio, video').forEach(other => {
            if (other !== event.target) other.pause();
        });
    }, true);
    document.querySelectorAll('audio.quiz-audio').forEach(audio => {
        audio.addEventListener('error', () => {
            audio.after(status);
            status.textContent = t.error;
        });
    });
    window.addEventListener('pagehide', () => {
        generation++;
        player.pause();
    });
})();
