import { computed, effect, signal } from "@preact/signals";
import { ArchiveListModel } from "./archive_list_model.js";
import { LogModel } from "./log_model.js";
import { PluginsModel } from "./plugins_model.js";

export const plugins = new PluginsModel();
export const categories = signal([]);
export const selectedTask = signal("plugin");
export const msmSelectionCount = signal(0);

export const archives = new ArchiveListModel([]);
export const log = new LogModel();

// User has stared a batch job. It may or may not be completed. (AKA show JobStatus)
export const batchJobIsRunning = signal(false);
export const batchJobIsNotRunning = computed(() => {
    return !batchJobIsRunning.value;
});
// User has completed a batch job. (AKA show "Start another job")
export const batchJobIsComplete = signal(false);
export const batchJobIsNotComplete = computed(() => {
    return !batchJobIsComplete.value;
});

export const treatedArchives = signal(0);
export const totalArchives = signal(0);
export const selectedCategory = signal("");
export const tagrules = signal("");
export const batchProgress = computed(() => {
    return treatedArchives.value / totalArchives.value;
});
export const overrideGlobalParameters = signal(false);
export const batchTimeout = signal(0);
export const overrideArgValues = signal([]);

// Default batch timeout to the selected plugin's recommended cooldown
effect(() => {
    batchTimeout.value = plugins.selectedPluginCooldown.value;
});

// Reset arg overrides when the selected plugin changes
effect(() => {
    const plugin = plugins.selectedPlugin.value;
    if (plugin && plugin.parameters) {
        overrideArgValues.value = plugin.parameters.map((arg) =>
            arg.type === "bool" ? 0 : (arg.default_value ?? "")
        );
    } else {
        overrideArgValues.value = [];
    }
});
