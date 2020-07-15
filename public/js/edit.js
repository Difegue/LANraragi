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

function updateOneShotArg() {

	//show input
	$("#arg_label").show();
	$("#arg").show();

	var arg = $('#plugin').find(":selected").get(0).getAttribute('arg') + " : ";

	//hide input for plugins without a oneshot argument field
	if (arg === " : ") {
		$("#arg_label").hide();
		$("#arg").hide();
	}

	$('#arg_label').html(arg);
}

function saveMetadata() {

	var id = $("#archiveID").val();

	const formData = new FormData();
    formData.append('tags', $("#tagText").val());
    formData.append('title', $("#title").val());

	return fetch(`api/archives/${id}/metadata`, {method: "PUT", body: formData})
		.then(response => response.ok ? response.json() : { success: 0, error: "Response was not OK" })
		.then((data) => {
			if (data.success) {
				$.toast({
					showHideTransition: 'slide',
					position: 'top-left',
					loader: false,
					heading: 'Saved Successfully!',
					icon: 'success'
				})
			} else {
				throw new Error(data.message);
			}
		})
		.catch(error => showErrorToast("Error while saving archive data :", error));

}

function runPlugin() {
	saveMetadata().then(()=>getTags());
}

function getTags() {

	$('#tag-spinner').css("display", "block");
	$('#tagText').css("opacity", "0.5");
	$('#tagText').prop("disabled", true);
	$('#plugin-table').hide();

	const pluginID = $("select#plugin option:checked").val();
	const archivID = $("#archiveID").val();
	const pluginArg = $("#arg").val()
	genericAPICall(`../api/plugin/use?plugin=${pluginID}&id=${archivID}&arg=${pluginArg}`, "POST", null,
		"Error while fetching tags :", function (result) {

			if (result.data.title && result.data.title != "") {

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
			else if (result.data.new_tags != "") {
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

		}).then(() => {
			$('#tag-spinner').css("display", "none");
			$('#tagText').prop("disabled", false);
			$('#tagText').css("opacity", "1");
			$('#plugin-table').show();
		});
}