import I18N from "i18n";
import { For } from "@preact/signals/utils";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

import { categories, selectedCategory } from "../store.js";

export function AddCategoryOptions() {
    function setCategory(e) {
        console.log(e.target.value);
        selectedCategory.value = e.target.value;
    }

    return html`
        <table>
            <tbody>
                <tr class="operation addcat-operation">
                    <td>${I18N.AddToCategoryColon}</td>
                    <td>
                        <select class="favtag-btn"  value=${selectedCategory} onchange=${setCategory}>
                            <${For} each=${categories}>
                                ${(item) => html`<option value=${item.id}>${item.name}</option>`}
                            </${For}>
                        </select>
                    </td>
                </tr>
            </tbody>
        </table>
    `;
}