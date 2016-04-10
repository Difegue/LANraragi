//ajax functions using jquery go here

//ajaxThumbnail(ID)
//Takes the ID, calls ajax.pl to generate/get the image for the thumbnail of the matching archive. 
//Uses functions from thumb.js.
//If it fails, returns 0.
function ajaxThumbnail(archiveId)
{

	showSpinner();


	$.get( "ajax.pl", { function: "thumbnail", id: archiveId } )
		.done(function( data ) {
			//alert(data);
			if (data=="") //shit workaround for occasional empty ajax returns
				ajaxThumbnail(archiveId);
			else
				showtrail(data);
			return data;
		})
		.fail(function() {
			showtrail(undefined);
			return 0;
		});

}

//saveArchiveData()
//Grabs the data in the edit.pl form and saves it to Redis.
function saveArchiveData()
{
	var postData = $("#editArchiveForm").serializeArray()
	var formURL = $("#editArchiveForm").attr("action")

	$.ajax(
	{
		url : formURL,
		type: "POST",
		data : postData,
		success:function(data, textStatus, jqXHR) 
		{
			$("#statusEdit").html("Metadata saved !");
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$("#statusEdit").html("Something went wrong while saving archive data : "+errorThrown);		
		}
	});

}

//saveArchiveCallback(callbackFunction,callbackArguments)
//Grabs the data in the edit.pl form and presaves it to Redis for tag Searches. Executes a callback when data is correctly saved.
function saveArchiveCallback(callback,arg1,arg2)
{
	var postData = $("#editArchiveForm").serializeArray()
	var formURL = $("#editArchiveForm").attr("action")

	$.ajax(
	{
		url : formURL,
		type: "POST",
		data : postData,
		success:function(data, textStatus, jqXHR) 
		{
			callback(arg1,arg2);
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$("#statusEdit").html("Something went wrong while saving archive data : "+errorThrown);		
		}
	});

}


//deleteArchive(id)
//Sends a DELETE request for that archive ID, deleting the Redis key and attempting to delete the archive file.
function deleteArchive(arcId)
{
	var formURL = $("#editArchiveForm").attr("action")
	var postData = $("#editArchiveForm").serializeArray()

	$.ajax(
	{
		url : formURL,
		type: "DELETE",
		data : postData,
		success:function(data, textStatus, jqXHR) 
		{
			if (data.success == "0")
				alert("Couldn't delete archive file. Archive metadata has been deleted properly. Please delete the file manually.");
			else
				alert("Successfully deleted "+data.success+" . Redirecting...");

			window.location.replace('./index.pl');
		
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$("#statusEdit").html("Something went wrong while deleting archive : "+textStatus);		
		}
	});

}

//ajaxTags(titleOrHash,isHash)
//Calls ajax.pl to get tags for the given title or image hash.
//Returns "ERROR" on failure.
function ajaxTags(arcId,isHash)
{
	$('#tag-spinner').css("display","block");
	$('#tagText').css("opacity","0.5");
	$('#tagText').prop("disabled", true);

	$.get( "ajax.pl", { function: "tags", ishash: isHash, id: arcId} )
		.done(function(data) {

			if (data=="NOTAGS")
				$("#statusEdit").html("No tags found !");
			else
				if ($('#tagText').val()=="")
					$('#tagText').val(data);
				else
					$('#tagText').val($('#tagText').val() + ", "+ data);

			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			return data;
		})
		.fail(function(data) {
			$("#statusEdit").html("An error occured while getting tags. "+data);
			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			return "ERROR";
		});

}

//Get the titles who have been checked in the batch tagging list and update their tags with ajax calls.
//method = 0 => Archive Titles
//method = 1 => Image Hashes
//method = 2 => nhentai
function massTag(method)
{
	$('#buttonstagging').hide();
	$('#processing').attr("style","");
	var checkeds = document.querySelectorAll('input[name=archive]:checked');

	//convert nodelist to array
	var arr = [];

	for (var i = 0, ref = arr.length = checkeds.length; i < ref; i++) 
		{ arr[i] = checkeds[i]; }

	makeCall(arr,method);
}

//subfunctions for treating the archive queue.
function makeCall(archivesToCheck,method)
{
	if (!archivesToCheck.length) 
	{
		$('#processedArchive').html("All done !");
		$('#tag-spinner').attr("style","display:none");
		$('#buttonstagging').show();
		return;
	}

	archive = archivesToCheck.shift();
	ajaxCall(archive,method,archivesToCheck);

}

function ajaxCall(archive,method,archivesToCheck)
{
	//Set title in processing thingo
	$('#processedArchive').html("Processing "+$('label[for='+archive.id+']').html());

	//Ajax call for getting and setting the tags
	$.get( "ajax.pl", { function: "tagsave", ishash: method, id: archive.id} )
	.done(function(data) { makeCall(archivesToCheck,method); })  //hurr callback
	.fail(function(data) { $("#statusEdit").html("An error occured while getting tags. "+data); });

}