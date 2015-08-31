//ajax functions using jquery go here

//ajaxThumbnail(ID)
//Takes the ID, calls ajax.pl to generate/get the image for the thumbnail of the matching archive. 
//If it fails, returns 0.
function ajaxThumbnail(archiveId)
{
	$.get( "ajax.pl", { function: "thumbnail", id: archiveId } )
		.done(function( data ) {
			return data;
		})
		.fail(function() {
			return 0;
		});

}


//ajaxTags(titleOrHash,isHash)
//Calls ajax.pl to get tags for the given title or image hash.
//Returns "ERROR" on failure.
function ajaxTags(tagInput,isHash)
{
	$('#tag-spinner').css("display","block");
	$('#tagText').css("background-color","lightgray");

	$.get( "ajax.pl", { function: "tags", ishash: isHash, input: tagInput} )
		.done(function( data ) {
			
			if (data=="NOTAGS")
				alert("No tags found !");
			else
				$('#tagText').val($('#tagText').val() + " "+ data);

			$('#tag-spinner').css("display","none");
			$('#tagText').css("background-color","white");
			return data;
		})
		.fail(function(data) {
			alert("An error occured while getting tags. "+data);
			$('#tag-spinner').css("display","none");
			$('#tagText').css("background-color","white");
			return "ERROR";
		});

}