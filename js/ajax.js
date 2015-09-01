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
			showtrail(data);
			return data;
		})
		.fail(function() {
			showtrail(undefined);
			return 0;
		});

}


//ajaxTags(titleOrHash,isHash)
//Calls ajax.pl to get tags for the given title or image hash.
//Returns "ERROR" on failure.
function ajaxTags(tagInput,isHash)
{
	$('#tag-spinner').css("display","block");
	$('#tagText').css("opacity","0.5");
	$('#tagText').prop("disabled", true);

	$.get( "ajax.pl", { function: "tags", ishash: isHash, input: tagInput} )
		.done(function( data ) {

			if (data=="NOTAGS")
				alert("No tags found !");
			else
				$('#tagText').val($('#tagText').val() + " "+ data);

			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			return data;
		})
		.fail(function(data) {
			alert("An error occured while getting tags. "+data);
			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			return "ERROR";
		});

}