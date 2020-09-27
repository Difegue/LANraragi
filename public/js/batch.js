// Check untagged archives, using the matching API endpoint.
function checkUntagged() {

    $.get("api/archives/untagged")
        .done(function (data) {

            // Check untagged archives
            data.forEach(id => {
                $('#' + id)[0].checked = true;
            });
        })
        .fail(function () {
            $.toast({
                showHideTransition: 'slide',
                position: 'top-left',
                loader: false,
                heading: "Error getting untagged archives!",
                icon: 'error'
            });
        });
}

//Get the titles who have been checked in the batch tagging list and update their tags.
//This crafts a JSON list to send to the batch tagging websocket service.
function startBatch() {

    $('.tag-options').hide();

    $("#log-container").html('Started Batch Tagging operation...\n************\n');
    $('#cancel-job').show();
    $('#restart-job').hide();
    $('.job-status').show();

    var checkeds = document.querySelectorAll('input[name=archive]:checked');
    var arginputs = $('.' + $('#plugin').val() + '-argvalue');

    //convert nodelist to json
    arcs = [];
    var args = [];

    for (var i = 0, ref = arcs.length = checkeds.length; i < ref; i++) { arcs[i] = checkeds[i].id; }
    $("#arcs").html(0);
    $("#totalarcs").html(arcs.length);
    $(".bar").attr("style", "width: 0%;");

    //Only add values into the override argument array if the checkbox is on
    if ($("#override")[0].checked) {
        for (var j = 0, ref = args.length = arginputs.length; j < ref; j++) {

            // Checkbox inputs are handled by looking at the checked prop instead of the value.
            if (arginputs[j].type != "checkbox")
                args[j] = arginputs[j].value;
            else
                args[j] = arginputs[j].checked ? 1 : 0;

        }
    }

    // Initialize websocket connection
    timeout = $('#timeout').val();
    commandBase = {
        plugin: $('#plugin').val(),
        args: args,
    };

    var wsProto = "ws://";
    if (location.protocol == 'https:') wsProto = "wss://";
    var batchSocket = new WebSocket(wsProto + window.location.host + "/batch/socket");

    batchSocket.onopen = function (event) {
        var command = commandBase;
        command.archive = arcs.splice(0, 1)[0];
        console.log(command);
        batchSocket.send(JSON.stringify(command));
    };

    batchSocket.onmessage = function (event) {

        // Update log
        updateBatchStatus(event);

        // If there are no archives left, end session
        if (arcs.length === 0) {
            batchSocket.close(1000);
            return;
        }

        $("#log-container").append('Sleeping for ' + timeout + ' seconds.\n');
        // Wait timeout and pass next archive
        setTimeout(function () {
            var command = commandBase;
            command.archive = arcs.splice(0, 1)[0];
            console.log(command);
            batchSocket.send(JSON.stringify(command));
        }, timeout * 1000);
    };

    batchSocket.onerror = batchError;
    batchSocket.onclose = endBatch;

    $('#cancel-job').on("click", function () {
        $("#log-container").append('Cancelling...\n');
        batchSocket.close();
    });
}

//On websocket message, update the UI to show the archive currently being treated
function updateBatchStatus(event) {

    var msg = JSON.parse(event.data);

    if (msg.success === 0) {
        $("#log-container").append('Plugin error while processing ID ' + msg.id + '(' + msg.message + ')\n');
    } else {
        $("#log-container").append('Processed ' + msg.id + '(Added tags: ' + msg.tags + ')\n');

        //Uncheck ID in list
        $('#' + msg.id)[0].checked = false;

        if (msg.title != "") {
            $("#log-container").append('Changed title to: ' + msg.title + '\n');
        }
    }

    //Update counts
    var count = $("#arcs").html();
    var total = $("#totalarcs").html();
    count++;
    $(".bar").attr("style", "width: " + count / total * 100 + "%;");
    $("#arcs").html(count);

    scrollLogs();
}

function batchError(event) {

    $("#log-container").append('************\nError! Terminating session.\n');
    scrollLogs();

    $.toast({
        showHideTransition: 'slide',
        position: 'top-left',
        loader: false,
        hideAfter: false,
        heading: 'An error occured during batch tagging!',
        text: 'Please check application logs.',
        icon: 'error'
    });
}

function endBatch(event) {

    var status = 'info';

    if (event.code === 1001)
        status = 'warning';

    $("#log-container").append('************\n' + event.reason + '(code ' + event.code + ')\n');
    scrollLogs();

    $.toast({
        showHideTransition: 'slide',
        position: 'top-left',
        loader: false,
        heading: "Batch Tagging complete!",
        text: '',
        icon: status
    });

    $('#cancel-job').hide();
    $('#restart-job').show();

}

function checkAll(btn) {
    $(".checklist > * > input:checkbox").prop("checked", btn.checked);
    btn.checked = !btn.checked;
}

function showOverride() {
    currentPlugin = $('#plugin').val();

    $(".arg-override").hide();

    if ($("#override")[0].checked)
        $("." + currentPlugin + "-arg").show();
}

function scrollLogs() {
    $("#log-container").scrollTop($("#log-container").prop("scrollHeight"));
}

function restartBatchUI() {
    $('.tag-options').show();
    $('.job-status').hide();
}
