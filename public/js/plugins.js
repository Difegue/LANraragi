/**
 * Plugins Operations.
 */
const Plugins = {};

Plugins.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.save", "#save", () => Server.saveFormData("#editPluginForm"));
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.apiURL("/"); });

    // Handler for file uploading.
    $("#fileupload").fileupload({
        url: "/config/plugins/upload",
        dataType: "json",
        done(e, data) {
            if (data.result.success) {
                LRR.toast({
                    heading: "Plugin successfully uploaded!",
                    text: `The plugin "${data.result.name}" has been successfully added. Refresh the page to see it.`,
                    icon: "info",
                    hideAfter: 10000,
                });
            } else {
                LRR.toast({
                    heading: "Error uploading plugin",
                    text: data.result.error,
                    icon: "error",
                    hideAfter: false,
                });
            }
        },

    });
};

jQuery(() => {
    Plugins.initializeAll();
});
