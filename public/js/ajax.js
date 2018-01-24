//Scripting for API calls

//ajaxThumbnail(ID)
//Takes the ID, calls ajax.pl to generate/get the image for the thumbnail of the matching archive. 
//Uses functions from thumb.js.
//If it fails, returns 0.
function ajaxThumbnail(archiveId)
{

	showSpinner();

	$.get( "api/thumbnail", { id: archiveId } )
		.done(function( data ) {
			if (data=="") //shit workaround for occasional empty ajax returns
				ajaxThumbnail(archiveId);
			else
				showtrail(data.thumbnail);
			return data;
		})
		.fail(function() {
			showtrail(undefined);
			return 0;
		});

}

//ajaxThumbnailThumbView(ID, repeat)
//Works similarly to ajaxThumbnail, but for Thumbnail View.
//Doesn't bother with the spinner and/or trail and just sets the image in the <img> DOM element with the ID_thumb id.
function ajaxThumbnailThumbView(archiveId, repeatOnFailure)
{
	$.get( "api/thumbnail", { id: archiveId } )
			.done(function(data) {

				if (data==="") {
						$('#'+archiveId+'_thumb').attr('src',"./img/noThumb.png"); //set to nothumb :(
						$('#'+archiveId+'_thumb + i').remove(); //remove the spinner icon
					}
				else {
					$('#'+archiveId+'_thumb').attr('src',data.thumbnail); //set image div source to the ajax result
					$('#'+archiveId+'_thumb + i').remove(); //remove the spinner icon
				}
			})
			.fail(function() {
				$('#'+archiveId+'_thumb').attr('src',"./img/noThumb.png"); //set to nothumb :(
				$('#'+archiveId+'_thumb + i').remove(); //remove the spinner icon
			});

}

//cleanTempFldr
function cleanTempFldr()
{

	$.get("api/cleantemp")
		.done(function( data ) {
			if (data.success) //shit workaround for occasional empty ajax returns
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Temporary Folder Cleaned!',
				    icon: 'success'
				});
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Error while cleaning Temporary Folder :',
				    text: data.error,
				    icon: 'error'
				});	
			$("#tempsize").html(data.newsize);
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
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Metadata saved!',
			    icon: 'success'
			})
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while saving archive data :',
			    text: errorThrown,
			    icon: 'error'
			})	
		}
	});

}

//saveConfigurationData()
//Grabs the data in the config.pl form and saves it to Redis. Very much a copypaste idgaf it's js wooooow
function saveConfigurationData()
{
	var postData = $("#editConfigForm").serializeArray()
	var formURL = $("#editConfigForm").attr("action")

	
	$.ajax(
	{
		url : formURL,
		type: "POST",
		data : postData,
		success:function(data, textStatus, jqXHR) 
		{
			if (data.success == "0")
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Error while saving configuration',
				    text: data.message,
				    icon: 'error'
				});		
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Configuration saved!',
				    icon: 'success'
				})
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while saving configuration :',
			    text: errorThrown,
			    icon: 'error'
			})		
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
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while saving archive data :',
			    text: errorThrown,
			    icon: 'error'
			});
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
			{
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: "Couldn't delete archive file. <br> (Maybe it has already been deleted beforehand?)",
				    text: 'Archive metadata has been deleted properly. <br> Please delete the file manually before returning to Library View.',
				    hideAfter: false,
				    icon: 'warning'
				});
				$(".stdbtn").hide();
				$("#goback").show();
			}
			else
			{
				$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Archive successfully deleted. Redirecting you ...',
			    text: 'File name : '+data.success, 
			    icon: 'success'
				});
				setTimeout("location.href = './';",1500);
			}
			
		
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while deleting archive :',
			    text: textStatus,
			    icon: 'error'
			});
		}
	});

}

//ajaxTags(titleOrHash,method)
//Calls API to get tags for the given title or image hash.
//Returns "ERROR" on failure.
function ajaxTags(arcId,method)
{
	$('#tag-spinner').css("display","block");
	$('#tagText').css("opacity","0.5");
	$('#tagText').prop("disabled", true);

	urlOverride = "";

	if (method === 0 || method === 2)
		urlOverride = prompt("If you wish to use tags from an existing E-Hentai/Nhentai archive you know of, enter its URL here. \n Otherwise, leave blank and we'll try to search for a match.", "");

	if (urlOverride === null) {

		$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Tag lookup aborted.',
				    icon: 'info'
				});

		$('#tag-spinner').css("display","none");
		$('#tagText').prop("disabled", false);
		$('#tagText').css("opacity","1");

		return "ERROR"; 
	}


	$.get( "api/tags", { method: method, id: arcId, url: urlOverride} )
		.done(function(data) {

			if (data==="NOTAGS")
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'No tags found!',
				    icon: 'info'
				});
			
			if (data==="NOTHUMBNAIL") {
					$.toast({
						showHideTransition: 'slide',
						position: 'top-left', 
						loader: false, 
						hideAfter: false,
					    heading: 'Thumbnail hash for this archive is unavailable. <br/>We\'ll try regenerating it, try again in a little while ! <br/>If this message appears multiple times, your archive might be broken.',
					    icon: 'error',
					});

					//fire a wild get to the fastest way to regenerate an archive, the reader with reload_thumbnail=1.
					$.get("./reader.pl?id="+arcId+"&reload_thumbnail=1");

			}
			
			if (data !="NOTAGS" && data !="NOTHUMBNAIL")
			{
				if ($('#tagText').val()=="")
					$('#tagText').val(data);
				else
					$('#tagText').val($('#tagText').val() + ", "+ data);

				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Added the following tags',
				    text: data,
				    icon: 'info'
				});

			}

			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			return data;
		})
		.fail(function(data) {
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while getting tags :',
			    text: data,
			    icon: 'error'
			});
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
	$('#processing').show();
	$('#tag-spinner').show();
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
		$('#tag-spinner').hide();
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
	$.get( "api/tags", { method: method, id: archive.id, instasave: 1} )
	.done(function(data) { makeCall(archivesToCheck,method); })  //hurr callback
	.fail(function(data) { $("#processedArchive").html("An error occured while getting tags. "+data); });

}