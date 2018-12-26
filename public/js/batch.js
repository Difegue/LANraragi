
function updatePluginArg() {

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

    //convert nodelist to json
    var arr = [];
    for (var i = 0, ref = arr.length = checkeds.length; i < ref; i++) { arr[i] = checkeds[i].id; }

    //give JSON to websocket and start listening
    var command = {
        plugin: $('#plugin').val(),
        args: "",
        timeout: $('#timeout').val(),
        archives: arr
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

function scrollLogs() {
    $("#log-container").scrollTop($("#log-container").prop("scrollHeight"));
}

function restartBatchUI() {
    $('.tag-options').show();
    $('.job-status').hide();
}
