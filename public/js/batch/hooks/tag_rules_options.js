import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
import { ApiURL, openInNewTab } from "../../mod/common.js";
import { tagrules } from "../store.js";
const html = htm.bind(h);

export function TagRulesOptions() {
    return html`
        <table>
            <tbody>
                <tr class="operation tagrules-operation">
                    <td style="vertical-align: top;">${I18N.ThisWillApplyTheFollowingTagRules}<br /><br />
                        ${I18N.YouCanEditTagRulesInServerConfiguration}<br /><br />
                        <input id='server-config' class='stdbtn' type='button' value=${I18N.ServerConfiguration} onclick=${() => openInNewTab(new ApiURL("/config"))} />
                    </td>
                    <td>
                        <textarea class="stdinput" size="20" style='height:196px' disabled>${tagrules.value}</textarea>
                    </td>
                </tr>
            </tbody>
        </table>
    `;
}