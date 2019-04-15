//Scripting for Generic API calls.

//Call that shows a popup to the user on success/failure.
function genericAPICall(endpoint, successMessage, errorMessage, callback) {
	$.get(endpoint)
		.done(function (data) {
			if (data.success)
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: successMessage,
					icon: 'success'
				});
			else
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: errorMessage,
					text: data.error,
					icon: 'error'
				});

			if (callback !== null)
				callback(data);
		})
		.fail(function () {
			$.toast({
				showHideTransition: 'slide',
				position: 'top-left',
				loader: false,
				heading: errorMessage,
				icon: 'error'
			});
		});
}

function cleanTempFldr() {

	genericAPICall("api/clean_temp", "Temporary Folder Cleaned!", "Error while cleaning Temporary Folder :",
		function (data) {
			$("#tempsize").html(data.newsize);
		});
}

function invalidateCache() {
	genericAPICall("api/discard_cache", "Started JSON Cache rebuild.", "Error while deleting cache! Check Logs.", null);
}

function clearNew() {
	genericAPICall("api/clear_new", "All archives are no longer new!", "Error while clearing flags! Check Logs.", null);
}

function rebootShinobu() {
	$("#restart-button").prop("disabled", true);
	genericAPICall("api/restart_shinobu", "Background Worker restarted!", "Error while restarting Worker:",
		function (data) {
			$("#restart-button").prop("disabled", false);
			shinobuStatus();
		});

}

//Update the status of the background worker.
function shinobuStatus() {
	$.get("api/shinobu_status")
		.done(function (data) {
			if (data.is_alive) {
				$("#shinobu-ok").show();
				$("#shinobu-ko").hide();
			} else {
				$("#shinobu-ko").show();
				$("#shinobu-ok").hide();
			}
			$("#pid").html(data.pid);

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
			url: formURL,
			type: "POST",
			data: postData,
			success: function (data, textStatus, jqXHR) {
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
			error: function (jqXHR, textStatus, errorThrown) {
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
