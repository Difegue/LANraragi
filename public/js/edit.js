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
	if (arg === " : ") {
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

	genericAPICall("../api/use_plugin?plugin="+$("select#plugin option:checked").val()+
					"&id="+$("#archiveID").val()+"&arg="+$("#arg").val(), 
					null, "Error while fetching tags :",
		function (result) {

			if (result.success) {

				if ( result.data.title && result.data.title != "" ) {
	
					$('#title').val(result.data.title);
					$.toast({
						showHideTransition: 'slide',
						position: 'top-left', 
						loader: false, 
						heading: 'Archive title changed to :',
						text: result.data.title,
						icon: 'info'
					});		
				}
	
				if ($('#tagText').val() === "") 
					$('#tagText').val(result.data.new_tags);
				else if ( result.data.new_tags != "" ) {
					$('#tagText').val($('#tagText').val() + "," + result.data.new_tags);
	
					$.toast({
							showHideTransition: 'slide',
							position: 'top-left', 
							loader: false, 
							heading: 'Added the following tags :',
							text: result.data.new_tags,
							icon: 'info'
						});		
				} else {
					$.toast({
							showHideTransition: 'slide',
							position: 'top-left', 
							loader: false, 
							heading: 'No new tags added!',
							text: result.data.new_tags,
							icon: 'info'
						});	
				}
			}

			$('#tag-spinner').css("display","none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity","1");
			$('#plugin-table').show();

		});

}