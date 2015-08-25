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
	$.get( "ajax.pl", { function: "tags", ishash: isHash, input: tagInput} )
		.done(function( data ) {
			return data;
		})
		.fail(function() {
			return "ERROR";
		});

}