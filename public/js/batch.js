function checkAll(btn) {
    $("input:checkbox").prop("checked", btn.checked);
    btn.checked = !btn.checked;
}

function updatePluginArg() {

}

//Get the titles who have been checked in the batch tagging list and update their tags.
//This crafts a JSON list to send to the batch tagging websocket service.
function startBatch() {

    $('.tag-options').hide();
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

    var batchSocket = new WebSocket("ws://"+window.location.host+"/batch/socket");

    batchSocket.onopen = function (event) {
        batchSocket.send(JSON.stringify(command)); 
      };

    batchSocket.onmessage = updateBatchStatus;
    batchSocket.onerror = batchError;
    batchSocket.onclose = endBatch;

}

//On websocket message, update the UI to show the archive currently being treated
function updateBatchStatus(event) {
    console.log(msg);
    var msg = JSON.parse(event.data);

    $('#job-status').html('Processed '+msg.id + '(Added tags: '+ msg.tags +')');

    if (msg.success === 0) {
        $.toast({
            showHideTransition: 'slide',
            position: 'top-left', 
            loader: false, 
            hideAfter: false,
            heading: 'Plugin error while processing ID '+msg.id,
            text: msg.message,
            icon: 'warning'
        });
    }

}

function batchError(event) {
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

    $.toast({
        showHideTransition: 'slide',
        position: 'top-left', 
        loader: false, 
        hideAfter: false,
        heading: event.reason,
        text: 'Batch Tagging completed. (code ' + event.code + ')',
        icon: status
    });

    $('.tag-options').show();
    $('.job-status').hide();
}

