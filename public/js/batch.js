//Get the titles who have been checked in the batch tagging list and update their tags with ajax calls.
//method = 0 => Archive Titles
//method = 1 => Image Hashes
//method = 2 => nhentai
function massTag(method) {

    $('#buttonstagging').hide();
    $('#processing').show();
    $('#tag-spinner').show();
    var checkeds = document.querySelectorAll('input[name=archive]:checked');

    //convert nodelist to array
    var arr = [];
    for (var i = 0, ref = arr.length = checkeds.length; i < ref; i++) { arr[i] = checkeds[i]; }
    makeCall(arr, method);

}

//subfunctions for treating the archive queue.
function makeCall(archivesToCheck, method) {

    if (!archivesToCheck.length) {
        $('#processedArchive').html("All done !");
        $('#tag-spinner').hide();
        $('#buttonstagging').show();
        return;
    }

    archive = archivesToCheck.shift();
    ajaxCall(archive, method, archivesToCheck);

}



function ajaxCall(archive, method, archivesToCheck) {

    //Set title in processing thingo
    $('#processedArchive').html("Processing " + $('label[for=' + archive.id + ']').html());

    //Ajax call for getting and setting the tags
    $.get("ajax.pl", { function: "tagsave", method: method, id: archive.id })
        .done(function (data) { makeCall(archivesToCheck, method); })  //hurr callback
        .fail(function (data) { $("#processedArchive").html("An error occured while getting tags. " + data); });
}