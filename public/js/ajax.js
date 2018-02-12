//Scripting for API calls

//cleanTempFldr
function cleanTempFldr()
{
	$.get("api/cleantemp")
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
