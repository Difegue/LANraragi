//JS functions meant for use in the Edit page. 
//Mostly dealing with plugins.

function toastHelpEdit() {
	
	$.toast({
				heading: 'About Plugins',
			    text: 'aaaaa',
			    hideAfter: false,
			    position: 'top-left', 
			    icon: 'info'
				});

}

function updateOneShotArg(){

	var arg = $('#plugin').find(":selected").get(0).getAttribute('arg')+" : ";

	//todo - hide input for plugins without a oneshot argument field
	$('#arg_label').html( arg );
}

//saveArchiveCallback(callbackFunction,callbackArguments)
//Grabs the data in the edit.pl form and presaves it to Redis for tag Searches. Executes a callback when data is correctly saved.
function saveArchiveCallback(callback,arg1,arg2){

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

function getTags() {

	$('#tag-spinner').css("display","block");
	$('#tagText').css("opacity","0.5");
	$('#tagText').prop("disabled", true);


	//$('#tagText').val(data);


	$('#tag-spinner').css("display","none");
	$('#tagText').prop("disabled", false);
	$('#tagText').css("opacity","1");


}

//deleteArchive(id)
//Sends a DELETE request for that archive ID, deleting the Redis key and attempting to delete the archive file.
function deleteArchive(arcId){

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