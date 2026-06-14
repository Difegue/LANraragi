import { computed, createModel, signal } from "@preact/signals";

/**
 * @typedef PluginParam
 * @property {string} desc
 * @property {string} type
 */

/**
 * @typedef Plugin
 * @property {string} icon
 * @property {string} author
 * @property {string} description 
 * @property {number} [cooldown]
 * @property {string} name
 * @property {string} [login_from]
 * @property {string} namespace
 * @property {string} oneshot_arg
 * @property {Array<PluginParam>} parameters
 * @property {string} type
 * @property {string} version
 */

export const PluginsModel = createModel(() => {
    const plugins = signal(/** @type Array<Plugin>*/[]);
    const selectedPluginNamespace = signal("");

    const selectedPlugin = computed(() => {
        if (!selectedPluginNamespace.value) {
            return null;
        }
        return plugins.value.find(p => p.namespace === selectedPluginNamespace.value);
    });

    const selectedPluginCooldown = computed(() => {
        return selectedPlugin.value?.cooldown ?? 0;
    });

    return {
        plugins,
        selectedPlugin,
        selectedPluginNamespace,
        selectedPluginCooldown,
        setPlugins(plugins) {
            this.plugins.value = plugins;
            this.selectedPluginNamespace.value = this.plugins.value[0]?.namespace;
        },
        getPlugin(namespace) {
            return this.plugins.value.find(p => p.namespace === namespace);
        },
        /**
         * @param {string} namespace
         */
        selectPlugin(namespace) {
            this.selectedPluginNamespace.value = namespace;
        },
    };
});
