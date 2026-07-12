import { selectedTask, archives } from "../store.js";

import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
import { PluginOptions } from "./plugin_options.js";
import { ClearNewOptions } from "./clear_new_options.js";
import { TagRulesOptions } from "./tag_rules_options.js";
import { AddCategoryOptions } from "./add_category_options.js";
import { DeleteOptions } from "./delete_options.js";
import * as LRR from "../../mod/common.js";
import { startBatch } from "../batch_service.js";
const html = htm.bind(h);

export function TaskOptions() {
    /**
     * Pop up a confirm dialog if operation is destructive.
     */
    async function startBatchCheck() {
        if (selectedTask.value === "delete") {
            const accept = await LRR.showPopUp({
                text: I18N.ConfirmArchivesDeletion,
                icon: "warning",
                showCancelButton: true,
                focusConfirm: false,
                confirmButtonText: I18N.ConfirmYes,
                reverseButtons: true,
                confirmButtonColor: "#d33",
            });
            if(accept.isConfirmed) {
                startBatch();
            }
        } else {
            startBatch();
        }
    }

    return html`
        <div class="id1 tag-options" style="padding:4px; height:unset; width:97%;">
            ${selectedTask.value === "plugin" && html`<${PluginOptions} />`}
            ${selectedTask.value === "clearnew" && html`<${ClearNewOptions} />`}
            ${selectedTask.value === "tagrules" && html`<${TagRulesOptions} />`}
            ${selectedTask.value === "addcat" && html`<${AddCategoryOptions} />`}
            ${selectedTask.value === "delete" && html`<${DeleteOptions} />`}
        </div>
        <div class="tag-options" style="text-align:center">
            <br/>
            <input type='button' value=${I18N.CheckUncheckAll} class='stdbtn' checked='false' onclick=${() => archives.toggleCheckAll()} />
            <input type='button' value=${I18N.StartTask} class='stdbtn' onclick=${startBatchCheck} />
        </div>
    `;
}
