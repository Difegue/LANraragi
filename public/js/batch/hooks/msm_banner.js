import I18N from "i18n";
import { archives, msmSelectionCount} from "../store.js";
import htm from "htm";
import { h } from "preact";

const html = htm.bind(h);

export function MsmBanner() {
    function discardMsmSelection() {
        localStorage.removeItem("msmSelection");
        msmSelectionCount.value = 0;
        archives.loadArchives();
    }

    return html`
        <div id="msm-banner" style="text-align:center;">
            <br />
            <b>${I18N.BatchSelectionBanner(msmSelectionCount.value)}</b>
            <br /><br />
            <input type='button' value=${I18N.DiscardSelection} class='stdbtn' onclick=${discardMsmSelection} />
        </div>
    `;
}