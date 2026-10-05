import { selectedTask } from "../store.js";
import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

export function TaskSelector() {
    return html`
        <table class="tag-options" style="margin-left: auto;margin-right: auto;">
            <tbody>
            <tr>
                <td>
                    <h2>${I18N.Tasks}</h2>
                </td>
                <td>
                    <select id="batch-operation" class="favtag-btn" style="font-size:20px; height:30px" value=${selectedTask} onChange=${(e) => { selectedTask.value = e.target.value; }}>
                        <option value="plugin">🧩 ${I18N.UsePlugin}</option>
                        <option value="clearnew">🆕 ${I18N.RemoveNewFlag }</option>
                        <option value="tagrules">📏 ${I18N.ApplyTagRules}</option>
                        <option value="addcat">📚 ${I18N.AddToCategory}</option>
                        <option value="delete">🗑️ ${I18N.DeleteArchive}</option>
                    </select>
                </td>
            </tr>
            </tbody>
        </table>
    `;
}
