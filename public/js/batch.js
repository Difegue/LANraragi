/**
 * Batch Operations
 * @global
 */
import * as LRR from "mod/common";
import * as Server from "mod/server";
import I18N from "i18n";

const Batch = {};

Batch.socket = {};
Batch.treatedArchives = 0;
Batch.totalArchives = 0;
Batch.currentOperation = "";
Batch.currentPlugin = "";

Batch.initializeAll = function () {
    // bind events to DOM
    $(document).on("change.batch-operation", "#batch-operation", Batch.selectOperation);
    $(document).on("change.plugin", "#plugin", Batch.showOverride);
    $(document).on("click.override", "#override", Batch.showOverride);
    $(document).on("click.check-uncheck", "#check-uncheck", Batch.checkAll);
    $(document).on("click.start-batch", "#start-batch", Batch.startBatchCheck);
    $(document).on("click.restart-job", "#restart-job", Batch.restartBatchUI);
    $(document).on("click.cancel-job", "#cancel-job", Batch.cancelBatch);
    $(document).on("click.server-config", "#server-config", () => LRR.openInNewTab(new LRR.ApiURL("/config")));
    $(document).on("click.plugin-config", "#plugin-config", () => LRR.openInNewTab(new LRR.ApiURL("/config/plugins")));
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.ApiURL("/"); });
    $(document).on("click.batch-reset-selection", "#batch-reset-selection", Batch.loadAllArchives);

    Batch.selectOperation();
    Batch.showOverride();


    // If a selected subset of archives is present, load only those archives.
    // Otherwise load the full archive list.
    const msmSelection = localStorage.getItem("msmSelection");
    if (msmSelection) {
        try {
            const ids = JSON.parse(msmSelection);
            if (Array.isArray(ids) && ids.length > 0) {
                Batch.loadSelectionOnly(ids);
                return;
            }
        } catch (e) {
            console.warn("Failed to parse msmSelection:", e);
        }
    }

    Batch.loadAllArchives();
};

/**
 * Show the matching rows depending on the selected operation.
 */
Batch.selectOperation = function () {
    Batch.currentOperation = $("#batch-operation").val();

    $(".operation").hide();
    $(`.${Batch.currentOperation}-operation`).show();
};

/**
 * Show the matching override arguments for the selected plugin.
 */
Batch.showOverride = function () {
    Batch.currentPlugin = $("#plugin").val();

    const cooldown = $(`#${Batch.currentPlugin}-timeout`).html();
    $("#cooldown").html(cooldown);
    $("#timeout").val(cooldown);

    $(".arg-override").hide();

    if ($("#override")[0].checked) { $(`.${Batch.currentPlugin}-arg`).show(); }
};

/**
 * Load only the archives from the MSM selection, fetching each archive's metadata individually.
 * Shows the MSM selection banner and pre-checks all loaded archives.
 * @param {string[]} ids Array of archive IDs from msmSelection
 */
Batch.loadSelectionOnly = function (ids) {

    const fetches = ids.map((id) =>
        Server.callAPI(`/api/archives/${id}/metadata`, "GET", null, null, (data) => data)
            .catch(() => null),
    );

    Promise.all(fetches).then((results) => {
        let hasTanks = false;
        let hasArchives = false;

        results.forEach((archive) => {
            if (!archive) return;
            const arcId = archive.arcid || archive.id;
            const escapedTitle = LRR.encodeHTML(archive.title) + (archive.isnew === "true" ? " 🆕" : "");
            const html = `<li><input type='checkbox' name='archive' id='${arcId}' class='archive' checked><label for='${arcId}'>${escapedTitle}</label></li>`;

            if (arcId.startsWith("TANK_")) {
                $("#tankoubonlist").append(html);
                hasTanks = true;
            } else {
                $("#archivelist").append(html);
                hasArchives = true;
            }
        });

        if (hasTanks) $("#no-tankoubons-msg").hide();
        if (hasArchives) $("#no-archives-msg").hide();

        // Show the MSM selection banner
        $("#msm-banner-count").text(I18N.BatchSelectionBanner(ids.length));
        $("#msm-banner").show();
    }).finally(() => {
        $("#arclist-container").show();
        $("#loading-placeholder").hide();
    });
};

/**
 * Load the full archive list from the API.
 * Hides the selection banner (if present) and prechecks untagged archives.
 */
Batch.loadAllArchives = function () {
    $("#tankoubonlist").empty();
    $("#archivelist").empty();
    $("#no-tankoubons-msg").show();
    $("#no-archives-msg").show();
    $("#msm-banner").html("");
    $("#arclist-container").hide();
    $("#loading-placeholder").show();

    // Clear selection if present
    localStorage.removeItem("msmSelection");

    const archivePromise = Server.callAPI("/api/archives", "GET", null, I18N.ArchiveListLoadFailure,
        (data) => {
            data.forEach((archive) => {
                const escapedTitle = LRR.encodeHTML(archive.title) + (archive.isnew === "true" ? " 🆕" : "");
                const html = `<li><input type='checkbox' name='archive' id='${archive.arcid}' class='archive' ><label for='${archive.arcid}'>${escapedTitle}</label></li>`;
                $("#archivelist").append(html);
            });

            if (data.length > 0) $("#no-archives-msg").hide();

            Server.callAPI("/api/archives/untagged", "GET", null, I18N.UntaggedLoadFailure,
                (data) => { preCheckInternal(data); },
            );
        },
    );

    const tankPromise = Server.callAPI("/api/tankoubons?page=-1", "GET", null, null,
        (data) => {
            data.result.forEach((tank) => {
                const escapedTitle = LRR.encodeHTML(tank.name);
                const html = `<li><input type='checkbox' name='archive' id='${tank.id}' class='archive' ><label for='${tank.id}'>${escapedTitle}</label></li>`;
                $("#tankoubonlist").append(html);
            });

            if (data.result.length > 0) $("#no-tankoubons-msg").hide();
        },
    );

    Promise.all([archivePromise, tankPromise]).finally(() => {
        $("#arclist-container").show();
        $("#check-uncheck").show();
        $("#loading-placeholder").hide();
    });
};


function preCheckInternal(ids) {
    ids.forEach((id) => {
        const checkbox = document.getElementById(id);

        if (checkbox != null) {
            checkbox.checked = true;
            // Prepend matching <li> element to the top of the list
            checkbox.parentElement.parentElement.prepend(checkbox.parentElement);
        }
    });
}

/**
 * Pop up a confirm dialog if operation is destructive.
 */
Batch.startBatchCheck = function () {
    if (Batch.currentOperation === "delete") {
        LRR.showPopUp({
            text: I18N.ConfirmArchivesDeletion,
            icon: "warning",
            showCancelButton: true,
            focusConfirm: false,
            confirmButtonText: I18N.ConfirmYes,
            reverseButtons: true,
            confirmButtonColor: "#d33",
        }).then((result) => {
            if (result.isConfirmed) {
                Batch.startBatch();
            }
        });
    } else {
        Batch.startBatch();
    }
};

/**
 * Get the titles who have been checked in the batch tagging list, and update their tags.
 * This crafts a JSON list to send to the batch tagging websocket service.
 */
Batch.startBatch = function () {
    $(".tag-options").hide();

    $("#log-container").html(I18N.BatchOperationStart + "\n************\n");
    $("#cancel-job").show();
    $("#restart-job").hide();
    $(".job-status").show();

    const checkeds = document.querySelectorAll("input[name=archive]:checked");

    // Extract IDs from nodelist
    const arcs = Array.from(checkeds).map((item) => item.id);
    let args = [];

    // Reset counts
    Batch.treatedArchives = 0;
    Batch.totalArchives = arcs.length;
    $("#arcs").html(0);
    $("#totalarcs").html(arcs.length);
    $(".bar").attr("style", "width: 0%;");

    // Only add values into the override argument array if the checkbox is on
    const arginputs = $(`.${Batch.currentPlugin}-argvalue`);
    if ($("#override")[0].checked) {
        args = Array.from(arginputs).map((item) => {
            // Checkbox inputs are handled by looking at the checked prop instead of the value.
            if (item.type !== "checkbox") {
                return item.value;
            } else {
                return item.checked ? 1 : 0;
            }
        });
    }

    // Initialize websocket connection
    const timeout = (Batch.currentOperation === "plugin") ? $("#timeout").val() : 0;
    const commandBase = {
        operation: Batch.currentOperation,
        plugin: Batch.currentPlugin,
        category: $("#category").val(),
        args,
    };

    // Close any existing connection
    // eslint-disable-next-line no-empty
    try { Batch.socket.close(); } catch { }

    let wsProto = "ws://";
    if (document.location.protocol === "https:") wsProto = "wss://";
    let socket_path = new LRR.ApiURL("/batch/socket");
    Batch.socket = new WebSocket(`${wsProto + window.location.host}${socket_path}`);

    Batch.socket.onopen = function () {
        const command = commandBase;
        command.archive = arcs.splice(0, 1)[0];
        // eslint-disable-next-line no-console
        console.log(command);
        Batch.socket.send(JSON.stringify(command));
    };

    Batch.socket.onmessage = function (event) {
        // Update log
        Batch.updateBatchStatus(event);

        // If there are no archives left, end session
        if (arcs.length === 0) {
            Batch.socket.close(1000);
            return;
        }

        if (timeout !== 0) {
            $("#log-container").append(I18N.BatchSleeping(timeout));
            $("#log-container").append("\n");
        }
        // Wait timeout and pass next archive
        setTimeout(() => {
            const command = commandBase;
            command.archive = arcs.splice(0, 1)[0];
            // eslint-disable-next-line no-console
            console.log(command);
            Batch.socket.send(JSON.stringify(command));
        }, timeout * 1000);
    };

    Batch.socket.onerror = Batch.batchError;
    Batch.socket.onclose = Batch.endBatch;
};

/**
 * On websocket message, update the UI to show the archive currently being treated
 * @param {*} event The websocket message
 */
Batch.updateBatchStatus = function (event) {
    const msg = JSON.parse(event.data);

    if (msg.success === 0) {
        $("#log-container").append(I18N.BatchOperationError(msg.id, msg.message));
    } else {
        switch (Batch.currentOperation) {
            case "plugin":
                $("#log-container").append(I18N.BatchSuccessPlugin(msg.id, Batch.currentPlugin, msg.tags));
                break;
            case "delete":
                $("#log-container").append(I18N.BatchSuccessDelete(msg.id, msg.filename));
                break;
            case "tagrules":
                $("#log-container").append(I18N.BatchSuccessTagRul(msg.id, msg.tags));
                break;
            case "addcat":
                // Append the message at the end of this log,
                // as it can contain the warning about the ID already being in the category
                $("#log-container").append(I18N.BatchSuccessCategr(msg.id, msg.category, msg.message));
                break;
            case "clearnew": {
                $("#log-container").append(I18N.BatchSuccessClrNew(msg.id));
                // Remove last character from matching row
                const t = $(`#${msg.id}`).next().text().replace("🆕", "");
                $(`#${msg.id}`).next().text(t);
                break;
            }
            default:
                $("#log-container").append(I18N.BatchUnknownOperat(Batch.currentOperation, msg.message));
                break;
        }

        $("#log-container").append("\n\n");

        // Uncheck ID in list
        $(`#${msg.id}`)[0].checked = false;

        if (msg.title !== undefined && msg.title !== "") {
            $("#log-container").append(I18N.BatchChangedTitle(msg.title));
            $("#log-container").append("\n");
        }
    }

    // Update counts
    Batch.treatedArchives += 1;

    const percentage = Batch.treatedArchives / Batch.totalArchives;
    $(".bar").attr("style", `width: ${percentage * 100}%;`);
    $("#arcs").html(Batch.treatedArchives);

    Batch.scrollLogs();
};

/**
 * Handle websocket errors.
 */
Batch.batchError = function () {
    $("#log-container").append("************\n" + I18N.BatchOperationFailed + "\n");
    Batch.scrollLogs();

    LRR.toast({
        heading: I18N.BatchFailHeader,
        text: I18N.BatchFailBody,
        icon: "error",
        hideAfter: false,
    });
};

/**
 * Handle WS connection close events.
 * @param {*} event The closing event
 */
Batch.endBatch = function (event) {
    let status = "info";

    if (event.code === 1001) { status = "warning"; }

    $("#log-container").append(`************\n${event.reason}(code ${event.code})\n`);
    Batch.scrollLogs();

    LRR.toast({
        heading: I18N.BatchOperationEnd,
        icon: status,
    });

    // Delete the search cache after a finished session
    Server.callAPI("/api/search/cache", "DELETE", null, I18N.ErrorDeletingCache, null);

    $("#cancel-job").hide();

    if (Batch.currentOperation === "delete") {
        $("#log-container").append(I18N.BatchReloadingPage + "\n");
        setTimeout(() => { window.location.reload(); }, 5000);
    } else {
        $("#restart-job").show();
    }
};

Batch.checkAll = function () {
    const btn = $("#check-uncheck")[0];

    $(".checklist > * > input:checkbox").prop("checked", btn.checked);
    btn.checked = !btn.checked;
};

Batch.scrollLogs = function () {
    $("#log-container").scrollTop($("#log-container").prop("scrollHeight"));
};

Batch.cancelBatch = function () {
    $("#log-container").append(I18N.BatchCancelling + "\n");
    Batch.socket.close();
};

Batch.restartBatchUI = function () {
    $(".tag-options").show();
    $(".job-status").hide();
};

jQuery(() => {
    Batch.initializeAll();
});
