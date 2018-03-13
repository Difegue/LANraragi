//JS functions meant for use in the Edit page. 
//Mostly dealing with plugins.

function toastHelpEdit() {
	
	$.toast({
				heading: 'About Plugins',
			    text: 'You can use plugins to automatically fetch metadata for this archive. <br/> Just select a plugin from the dropdown and hit Go! <br/> Some plugins might provide an optional argument for you to specify. If that\'s the case, a textbox will be available to input said argument.',
			    hideAfter: false,
			    position: 'top-left', 
			    icon: 'info'
				});

}

function updateOneShotArg(){

	//show input
	$("#arg_label").show();
	$("#arg").show();

	var arg = $('#plugin').find(":selected").get(0).getAttribute('arg')+" : ";

	//hide input for plugins without a oneshot argument field
	if (arg === "") {
		$("#arg_label").hide();
		$("#arg").hide();
	}

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
	$('#plugin-table').hide();


	$.post( "/api/use_plugin", { id: $("#archiveID").val(), plugin: $("select#plugin option:checked").val(), arg: $("#arg").val() })
	  .done(function( data ) {

	    if (data.success) {
	    	if ($('#tagText').val() === "") 
	    		$('#tagText').val(data.tags);
	    	else 
	    		$('#tagText').val($('#tagText').val() + "," + data.tags);

	    	$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Added the following tags :',
				    text: data.tags,
				    icon: 'info'
				});		
	    } else {
	    	$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Error :',
				    text: data.message,
				    icon: 'error'
				});		
	    }
	    
	  })
	  .fail(function(data) {

  		$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error :',
			    text: data,
			    icon: 'error'
			});	

	  })
	  .always(function(data) {
	  	$('#tag-spinner').css("display","none");
		$('#tagText').prop("disabled", false);
		$('#tagText').css("opacity","1");
		$('#plugin-table').show();
	  });

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