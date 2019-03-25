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
    var arcs = [];
    var args = [];

    for (var i = 0, ref = arcs.length = checkeds.length; i < ref; i++) { arcs[i] = checkeds[i].id; }

    //Only add values into the override argument array if the checkbox is on
    if ($("#override")[0].checked) {
        for (var j = 0, ref = args.length = arginputs.length; j < ref; j++) { args[j] = arginputs[j].value; }
    }
    console.log(args);
    //give JSON to websocket and start listening
    var command = {
        plugin: $('#plugin').val(),
        args: args,
        timeout: $('#timeout').val(),
        archives: arcs
    };

    var batchSocket = new WebSocket("ws://" + window.location.host + "/batch/socket");

    batchSocket.onopen = function (event) {
        batchSocket.send(JSON.stringify(command));
    };

    batchSocket.onmessage = updateBatchStatus;
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

        if ( msg.title != "" ) {
            $("#log-container").append('Changed title to: ' + msg.title + '\n');
        }

        if ( msg.timeout != 0 ) {
            $("#log-container").append('Sleeping for ' + msg.timeout + ' seconds.\n');
        }
    }

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
