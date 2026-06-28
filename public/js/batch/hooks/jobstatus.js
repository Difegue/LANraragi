import htm from "htm";
import { h } from "preact";
import { cancelBatch, restartBatch } from "../batch_service.js";
import I18N from "i18n";
import {
    batchJobIsComplete,
    batchJobIsNotComplete,
    batchProgress,
    log,
    totalArchives,
    treatedArchives
} from "../store.js";
import { For, Show } from "@preact/signals/utils";
import { useEffect, useRef } from "preact/hooks";
const html = htm.bind(h);

export function JobStatus() {
    const logRef = useRef(null);

    useEffect(() => {
        const el = logRef.current;
        if (!el) return;
        const isAtBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 5;
        if (!isAtBottom) {
            el.scrollTop = el.scrollHeight;
        }
    }, [log.rows.value.length]);

    return html`
        <div class="job-status" style="text-align:center">
            <${Show} when=${batchJobIsNotComplete}>
                <input type='button' value=${I18N.Cancel} class='stdbtn' onclick=${cancelBatch} />
            </${Show}>
            <${Show} when=${batchJobIsComplete}>
                <input type='button' value=${I18N.StartAnotherJob} class='stdbtn' onclick=${restartBatch} />
            </${Show}>
            <div id="progress" style="padding-top:6px; padding-bottom:6px">
                <div class="bar" style=${`width:${batchProgress.value * 100}%`}></div>
                ${I18N.ProcessedXofY.replace("%1", treatedArchives.value).replace("%2", totalArchives.value)}
            </div>
            <div class="id1" style="padding:4px; height:auto; width:97%;">
                <pre ref=${logRef} class="log-panel">
                    <${For} each=${log.rows}>
                        ${(item) => html`${item}<br/>`}
                    </${For}>
                </pre>
            </div>
        </div>
    `;
}