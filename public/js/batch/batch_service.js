import I18N from "i18n";
import {
    archives,
    batchJobIsComplete,
    batchJobIsRunning,
    batchTimeout,
    log,
    overrideArgValues,
    overrideGlobalParameters,
    plugins,
    selectedCategory,
    selectedTask,
    totalArchives,
    treatedArchives
} from "./store.js";
import * as Server from "../mod/server.js";
import * as LRR from "../mod/common.js";
import { batch } from "@preact/signals";

let socket = null;
let currentPlugin = "";
let currentOperation = "";

/**
 * Get the titles who have been checked in the batch tagging list, and update their tags.
 * This crafts a JSON list to send to the batch tagging websocket service.
 */
export function startBatch() {
    currentPlugin = plugins.selectedPluginNamespace.value;
    currentOperation = selectedTask.value;

    log.clear();
    log.addRow(I18N.BatchOperationStart);
    log.addRow("************");

    // Extract IDs from nodelist
    const arcs = [...archives.checkedArchiveIds.value];
    let args = [];

    // Reset status
    batch(() => {
        batchJobIsRunning.value = true;
        batchJobIsComplete.value = false;
        treatedArchives.value = 0;
        totalArchives.value = arcs.length;
    });

    if (overrideGlobalParameters.value) {
        args = overrideArgValues.value;
    }

    // Initialize websocket connection
    const timeout = (currentOperation === "plugin") ? batchTimeout.value : 0;
    const commandBase = {
        operation: currentOperation,
        plugin: currentPlugin,
        category: selectedCategory.value,
        args,
    };

    // Close any existing connection
    if (socket !== null) {
        socket.close();
    }

    let wsProto = "ws://";
    if (document.location.protocol === "https:") wsProto = "wss://";
    let socket_path = new LRR.ApiURL("/batch/socket");
    socket = new WebSocket(`${wsProto + window.location.host}${socket_path}`);

    socket.onopen = function () {
        const command = commandBase;
        command.archive = arcs.splice(0, 1)[0];
        socket.send(JSON.stringify(command));
    };

    socket.onmessage = function (event) {
        // Update log
        updateBatchStatus(event);

        // If there are no archives left, end session
        if (arcs.length === 0) {
            socket.close(1000);
            return;
        }

        if (timeout !== 0) {
            log.addRow(I18N.BatchSleeping(timeout));
        }
        // Wait timeout and pass next archive
        setTimeout(() => {
            const command = commandBase;
            command.archive = arcs.splice(0, 1)[0];
            socket.send(JSON.stringify(command));
        }, timeout * 1000);
    };

    socket.onerror = batchError;
    socket.onclose = endBatch;
}

/**
 * On websocket message, update the UI to show the archive currently being treated
 * @param {*} event The websocket message
 */
function updateBatchStatus(event) {
    const msg = JSON.parse(event.data);

    if (msg.success === 0) {
        log.addRow(I18N.BatchOperationError(msg.id, msg.message));
    } else {
        switch (currentOperation) {
            case "plugin":
                log.addRow(I18N.BatchSuccessPlugin(msg.id, currentPlugin, msg.tags));
                break;
            case "delete":
                log.addRow(I18N.BatchSuccessDelete(msg.id, msg.filename));
                // Remove the archive from the listing
                archives.archives.value = archives.archives.value.filter(a => a.arcid !== msg.id);
                break;
            case "tagrules":
                log.addRow(I18N.BatchSuccessTagRul(msg.id, msg.tags));
                break;
            case "addcat":
                // Append the message at the end of this log,
                // as it can contain the warning about the ID already being in the category
                log.addRow(I18N.BatchSuccessCategr(msg.id, msg.category, msg.message));
                break;
            case "clearnew": {
                log.addRow(I18N.BatchSuccessClrNew(msg.id));
                // Update the new flag in the archive list model
                archives.archives.value = archives.archives.value.map(a =>
                    a.arcid === msg.id ? { ...a, isnew: false } : a
                );
                break;
            }
            default:
                log.addRow(I18N.BatchUnknownOperat(currentOperation, msg.message));
                break;
        }

        log.addRow("");
        log.addRow("");

        // Uncheck ID in list
        archives.uncheck(msg.id);

        if (msg.title !== undefined && msg.title !== "") {
            log.addRow(I18N.BatchChangedTitle(msg.title));
        }
    }

    // Update counts
    treatedArchives.value += 1;
}

export function cancelBatch() {
    log.addRow(I18N.BatchCancelling);
    if (socket) {
        socket.close();
        socket = null;
    }
}

export function restartBatch() {
    if (socket) {
        socket.close();
        socket = null;
    }
    batchJobIsRunning.value = false;
    batchJobIsComplete.value = false;
    log.clear();
}

/**
 * Handle websocket errors.
 */
function batchError() {
    log.addRow("************");
    log.addRow(I18N.BatchOperationFailed);

    LRR.toast({
        heading: I18N.BatchFailHeader,
        text: I18N.BatchFailBody,
        icon: "error",
        hideAfter: false,
    });
}

/**
 * Handle WS connection close events.
 * @param {*} event The closing event
 */
function endBatch(event) {
    let status = "info";

    if (event.code === 1001) { status = "warning"; }

    log.addRow(`************`);
    log.addRow(`${event.reason}(code ${event.code})`);

    LRR.toast({
        heading: I18N.BatchOperationEnd,
        icon: status,
    });

    // Delete the search cache after a finished session
    Server.callAPI("/api/search/cache", "DELETE", null, I18N.ErrorDeletingCache, null);

    batchJobIsComplete.value = true;
}
