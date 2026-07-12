import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

export function ClearNewOptions() {
    return html`
        <table>
            <tbody>
                <tr class="operation clearnew-operation">
                    <td colspan="2" style="text-align: center;">
                        ${I18N.ThisRemovesTheNewFlag}
                        <br/>
                    </td>
                </tr>
            </tbody>
        </table>
    `;
}
