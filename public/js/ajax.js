//Scripting for Generic API calls.

//cleanTempFldr
function cleanTempFldr(){

	$.get("api/clean_temp")
		.done(function( data ) {
			if (data.success) 
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


//invalidateCache
function invalidateCache() {
	$.get("api/discard_cache")
		.done(function( data ) {
			if (data.status) 
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'JSON Cache Deleted.',
				    icon: 'success'
				});
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Error while deleting cache! Check Logs.',
				    icon: 'error'
				});	
		});
}

//invalidateCache
function clearNew() {
	$.get("api/clear_new")
		.done(function( data ) {
			if (data.status) 
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'All archives are no longer new!',
				    icon: 'success'
				});
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Error while clearing flags! Check Logs.',
				    icon: 'error'
				});	
		});
}

//saveFormData()
//POSTs the data of the specified form to the page.
//This is used for Edit, Config and Plugins.
function saveFormData(formSelector) {

	var postData = $(formSelector).serializeArray()
	var formURL = $(formSelector).attr("action")

	
	$.ajax(
	{
		url : formURL,
		type: "POST",
		data : postData,
		success:function(data, textStatus, jqXHR) 
		{
			if (data.success)
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Saved Successfully!',
				    icon: 'success'
				})
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left', 
					loader: false, 
				    heading: 'Saving unsuccessful :',
				    text: data.message,
				    icon: 'error'
				});		
				
		},
		error: function(jqXHR, textStatus, errorThrown) 
		{
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left', 
				loader: false, 
			    heading: 'Error while saving :',
			    text: errorThrown,
			    icon: 'error'
			})		
		}
	});


}
