import { For, Show } from "@preact/signals/utils";
import { batchTimeout, overrideArgValues, overrideGlobalParameters, plugins } from "../store.js";
import I18N from "i18n";
import htm from "htm";
import { h } from "preact";
const html = htm.bind(h);

export function PluginOptions() {
    const inputTypes = {
        string: { type: "text", prop: "value", extract: (e) => e.target.value },
        int:    { type: "number", prop: "value", extract: (e) => e.target.value },
        bool:   { type: "checkbox", prop: "checked", extract: (e) => e.target.checked ? 1 : 0 },
    };

    function handleInput(index, cfg, e) {
        const vals = [...overrideArgValues.value];
        vals[index] = cfg.extract(e);
        overrideArgValues.value = vals;
    }

    function selectPlugin(e) {
        plugins.selectPlugin(e.target.value);
    }

    function argInput(index, arg) {
        const cfg = inputTypes[arg.type] || inputTypes.string;
        const val = overrideArgValues.value[index];

        return html`
        <input class="stdinput" type=${cfg.type}
            checked=${cfg.prop === "checked" ? val === 1 : undefined}
            value=${cfg.prop !== "checked" ? val : undefined}
            onChange=${(e) => handleInput(index, cfg, e)} />
    `;
    }

    return html`
        <table>
            <tbody>
                <tr class="operation plugin-operation">
                    <td>${I18N.UsePlugin}</td>
                    <td>
                        <select id="plugin" class="favtag-btn" value=${plugins.selectedPluginNamespace} onchange=${selectPlugin}>
                            <${For} each=${plugins.plugins}>
                                ${(item) => html`<option value=${item.namespace}>${item.name}</option>`}
                            </${For}>
                        </select>
                    </td>
                </tr>
                <tr class="operation plugin-operation">
                    <td>${I18N.Timeout}</td>
                    <td>
                        <input type="number" id="timeout" min="0" max="20" value=${batchTimeout} onInput=${(e) => batchTimeout.value = parseInt(e.target.value, 10) || 0} /> seconds
                    </td>
                </tr>
                <tr class="operation plugin-operation">
                    <td colspan="2">
                        <h3>${I18N.PluginRecommendsCooldown(plugins.selectedPluginCooldown)}</h3>
                        <p>
                            <i class="fas fa-exclamation-triangle"></i> ${I18N.SomeServicesMayBanYou}
                        </p>
                        <p dangerouslySetInnerHTML=${{ __html: I18N.SetASuitableTimeout }} />
                    </td>
                </tr>
                <tr class="operation plugin-operation">
                    <td colspan="2">
                        <input type="checkbox" id="override" checked=${overrideGlobalParameters} onchange=${(e) => overrideGlobalParameters.value = e.target.checked} />
                        <label for="override">${I18N.OverridePluginGlobalArguments}</label>
                    </td>
                </tr>
            </tbody>
        </table>

        <${Show} when=${overrideGlobalParameters}>
            <table class="operation plugin-operation">
                <tbody>
                    <${For} each=${plugins.selectedPlugin.value.parameters}>
                        ${(arg, index) => html`
                            <tr class="arg-override">
                                <td style="max-width:250px">${arg.desc} :</td>
                                <td>${argInput(index, arg)}</td>
                            </tr>
                        `}
                    </${For}>
                </tbody>
            </table>
        </${Show}>
    `;
}