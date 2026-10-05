import { archives } from "../store.js";
import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

export function ArchiveListing() {
    const model = archives;

    /**
     * @param {Archive} archive
     * @returns {string}
     */
    function archiveTitle(archive) {
        if (archive.isnew) {
            return `${archive.title} 🆕`;
        }
        return archive.title;
    }

    function changeChecked(e, arcid) {
        e.preventDefault();
        if (e.target.checked) {
            model.check(arcid);
        } else {
            model.uncheck(arcid);
        }
    }

    // TODO: Add free-text filtering
    return html`
        <div id="archivesection">
            ${model.anyArchives.value && html` 
                <ul class="checklist" id="archivelist" style="list-style: none; padding-left: 0; margin: 0;">
                    ${model.archives.value.map((/** @type {Archive}*/archive) => html`
                        <li>
                            <input type="checkbox" name="archive" 
                                   id=${archive.arcid}
                                   checked=${model.isChecked.value(archive.arcid)}
                                   onchange=${(e) => changeChecked(e, archive.arcid)}
                                   class="archive" />
                            <label for=${archive.arcid}>${archiveTitle(archive)}</label>
                        </li>
                    `)}
                </ul>
            `}
            ${!model.anyArchives.value && !model.loading.value && html`
                <p id="no-archives-msg" style="font-style: italic;">${I18N.NoArchivesInYourLibraryYet}</p>
            `}
            ${model.loading.value && html`
                <div id="loading-placeholder"
                     style="align-content: center;top: 150px; position: relative; margin-left: auto; margin-right: auto; width: 90%;">
                    <i class="fas fa-8x fa-spin fa-compact-disc"></i><br /><br />
                    <h2>${I18N.PreparingYourData}</h2>
                </div>
            `}
        </div>
    `;
}