/**
 * Plugins Operations.
 */
const Plugins = {};

Plugins.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.save", "#save", () => Server.saveFormData("#editPluginForm"));
    $(document).on("click.return", "#return", () => { window.location.replace("/"); });

    // Handler for file uploading.
    $("#fileupload").fileupload({
        url: "/config/plugins/upload",
        dataType: "json",
        done(e, data) {
            if (data.result.success) {
                $.toast({
                    heading: "Plugin successfully uploaded!",
                    text: `The plugin "${data.result.name}" has been successfully added. Refresh the page to see it.`,
                    hideAfter: false,
                    position: "top-left",
                    icon: "info",
                });
            } else {
                $.toast({
                    heading: "Error uploading plugin",
                    text: data.result.error,
                    hideAfter: false,
                    position: "top-left",
                    icon: "error",
                });
            }
        },

    });
};

jQuery(() => {
    Plugins.initializeAll();
});

window.Plugins = Plugins;
