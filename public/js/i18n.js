document.addEventListener('DOMContentLoaded', () => {
    try {
        const language = getCurrentLanguage();
        localStorage.setItem('language', language);
        console.log(`Initializing language: ${language}`);
        initializeI18next(language);
    } catch (error) {
        console.error('Error initializing language:', error);
        initializeI18next('en');
    }
});

/**
 * Get the current language from the DOM or localStorage
 * @returns {string} The current language
 */
function getCurrentLanguage() {
    const languageElement = document.getElementById('currentLanguage');
    return (languageElement && languageElement.value)
        ? languageElement.value
        : localStorage.getItem('language') || 'en';
}

/**
 * Initialize i18next
 * @param {string} language - The current language
 */
function initializeI18next(language) {
    i18next.use(i18nextHttpBackend).init({
        fallbackLng: 'en',
        backend: {
            loadPath: '/locales/{{lng}}.json'
        },
        lng: language
    }, (err, t) => {
        if (err) {
            console.error('Failed to initialize i18next:', err);
        } else {
            updateContent();
            document.dispatchEvent(new CustomEvent('i18nextInitialized'));
        }
    });
}

/**
 * Update the translations of the page content
 */
function updateContent() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const i18nKey = el.getAttribute('data-i18n');
        const i18nAttr = el.getAttribute('data-i18n-attr');
        const translation = i18next.t(i18nKey);

        if (el.tagName.toLowerCase() === 'select') {
            updateSelectOptions(el);
        } else {
            updateElementContent(el, i18nAttr, translation);
        }
    });
}

/**
 * Update the translations of the select options
 * @param {HTMLSelectElement} selectEl - The select element
 */
function updateSelectOptions(selectEl) {
    selectEl.querySelectorAll('option').forEach(option => {
        const i18nKey = option.getAttribute('data-i18n');
        if (i18nKey) {
            option.innerText = i18next.t(i18nKey);
        }
    });
}

/**
 * Update the translations of an element's content
 * @param {HTMLElement} el - The element to update
 * @param {string} i18nAttr - Optional HTML attribute to update content
 * @param {string} translation - The translated text
 */
function updateElementContent(el, i18nAttr, translation) {
    if (!translation) {
        const i18nKey = el.getAttribute('data-i18n');
        translation = i18next.t(i18nKey, { lng: 'en' });

        if (!translation) {
            console.error(`Translation missing for key: ${i18nKey}`);
            translation = 'Translation missing';
        }
    }

    if (i18nAttr) {
        el.setAttribute(i18nAttr, translation);
        return;
    }

    if (el.tagName.toLowerCase() === 'input' && (el.type === 'button' || el.type === 'submit')) {
        el.value = translation;
        return;
    }

    if (el.dataset.i18nHtml !== undefined) {
        el.innerHTML = translation;
    } else {
        el.innerText = translation;
    }

    sanitizeAndSetInnerHTML(el, translation);
}

/**
 * @param {HTMLElement} el - The element to update
 * @param {string} html - The HTML content to set
 */
function sanitizeAndSetInnerHTML(el, html) {
    const allowedTags = ['div', 'td', 'span', 'label', 'table'];
    if (allowedTags.includes(el.tagName.toLowerCase())) {
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        el.innerHTML = '';
        while (tempDiv.firstChild) {
            el.appendChild(tempDiv.firstChild);
        }
    }
}