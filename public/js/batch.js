/**
 * Batch Operations.
 */
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
    $(document).on("click.server-config", "#server-config", () => LRR.openInNewTab(new LRR.apiURL("/config")));
    $(document).on("click.plugin-config", "#plugin-config", () => LRR.openInNewTab(new LRR.apiURL("/config/plugins")));
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.apiURL("/"); });

    Batch.selectOperation();
    Batch.showOverride();

    // Load all archives, showing a spinner while doing so
    $("#arclist").hide();

    Server.callAPI("/api/archives", "GET", null, I18N.ArchiveListLoadFailure,
        (data) => {
            // Parse the archive list and add <li> elements to arclist
            data.forEach((archive) => {
                const escapedTitle = LRR.encodeHTML(archive.title) + (archive.isnew === "true" ? " 🆕" : "");
                const html = `<li><input type='checkbox' name='archive' id='${archive.arcid}' class='archive' ><label for='${archive.arcid}'>${escapedTitle}</label></li>`;
                $("#arclist").append(html);
            });

            Batch.checkUntagged();
        },
    )
        .finally(() => {
            $("#arclist").show();
            $("#loading-placeholder").hide();
        });
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
 * Check untagged archives, using the matching API endpoint.
 */
Batch.checkUntagged = function () {
    Server.callAPI("/api/archives/untagged", "GET", null, I18N.UntaggedLoadFailure,
        (data) => {
            // Check untagged archives
            data.forEach((id) => {
                const checkbox = document.getElementById(id);

                if (checkbox != null) {
                    checkbox.checked = true;
                    // Prepend matching <li> element to the top of the list
                    checkbox.parentElement.parentElement.prepend(checkbox.parentElement);
                }
            });
        },
    );
};

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
    let socket_path = new LRR.apiURL("/batch/socket");
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
            $("#log-container").append(I18N.BatchSuccessCategr(msg.id,msg.category,msg.message));
            break;
        case "clearnew": {
            $("#log-container").append(I18N.BatchSuccessClrNew(msg.id));
            // Remove last character from matching row
            const t = $(`#${msg.id}`).next().text().replace("🆕", "");
            $(`#${msg.id}`).next().text(t);
            break;
        }
        default:
            $("#log-container").append(I18N.BatchUnknownOperat(Batch.currentOperation,msg.message));
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
