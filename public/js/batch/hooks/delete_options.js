import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

export function DeleteOptions() {
    return html`
        <table>
            <tbody>
                <tr class="operation delete-operation">
                    <td></td>
                    <td style="font-size:36px; text-align: center;">
                        💣👀💦💦
                    </td>
                </tr>
                <tr class="operation delete-operation">
                    <td colspan="2" style="text-align: center;">
                        <h3>${I18N.ThisWillDeleteMetadataAndFiles}</h3>
                        <br />
                    </td>
                </tr>
            </tbody>
        </table>
    `;
}