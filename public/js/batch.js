/**
 * Batch Operations
 */
import { h, render } from "preact";
import htm from "htm";
import * as LRR from "./mod/common.js";
import { TaskSelector } from "./batch/hooks/task_selector.js";
import { TaskOptions } from "./batch/hooks/task_options.js";
import { ArchiveListing } from "./batch/hooks/archive_listing.js";
import { Show } from "@preact/signals/utils";
import {
    batchJobIsNotRunning,
    batchJobIsRunning,
    plugins,
    categories,
    archives,
    selectedCategory,
    tagrules,
    msmSelectionCount,
} from "./batch/store.js";
import { JobStatus } from "./batch/hooks/jobstatus.js";
import { MsmBanner } from "./batch/hooks/msm_banner.js";

const html = htm.bind(h);

function App() {
    return html`
        <div style="text-align:left; width:400px !important" class="left-column">
            <${Show} when=${msmSelectionCount}>
                <${MsmBanner} />
            </${Show}>
            <${Show} when=${batchJobIsNotRunning}>
                <${TaskSelector} />
                <${TaskOptions} />
            </${Show}>
            <${Show} when=${batchJobIsRunning}>
                <${JobStatus} />
            </${Show}>
        </div>
        <div class="id1 right-column" style="text-align:center; min-width:400px; width: 60% !important; height:500px;">
            <${ArchiveListing} />
        </div>
    `;
}

async function loadMsmSelection() {
    const msmSelection = localStorage.getItem("msmSelection");
    if (msmSelection) {
        try {
            const ids = JSON.parse(msmSelection);
            if (Array.isArray(ids) && ids.length > 0) {
                msmSelectionCount.value = ids.length;
                await archives.loadSelectionOnly(ids);
                return true;
            }
        } catch (e) {
            console.warn("Failed to parse msmSelection:", e);
        }
    }
    return false;
}

export async function initializeAll(config) {
    plugins.setPlugins(config.plugins);
    categories.value = config.categories;
    selectedCategory.value = categories.value[0]?.id ?? "";
    tagrules.value = config.tagrules;

    render(html`<${App} />`, document.getElementById("app"));

    // Didn't really see the point in moving these to preact
    document.getElementById("plugin-config").addEventListener("click", () => LRR.openInNewTab(new LRR.ApiURL("/config/plugins")));
    document.getElementById("return").addEventListener("click", () => { window.location.href = new LRR.ApiURL("/"); });

    if(!await loadMsmSelection()) {
        await archives.loadArchives();
    }
}
