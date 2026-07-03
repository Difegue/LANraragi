/**
 * Plugins Operations
 */
import * as Server from "./mod/server.js";
import * as LRR from "./mod/common.js";
import I18N from "i18n";

const Plugins = {};

Plugins.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.save", "#save", () => Server.saveFormData("#editPluginForm"));
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.ApiURL("/"); });

    // Handler for file uploading.
    $("#fileupload").fileupload({
        url: "/config/plugins/upload",
        dataType: "json",
        done(e, data) {
            if (data.result.success) {
                LRR.toast({
                    heading: I18N.PluginUploadSuccess,
                    text: I18N.PluginUploadDesc(data.result.name),
                    icon: "info",
                    hideAfter: 10000,
                });
            } else {
                LRR.toast({
                    heading: I18N.PluginUploadError,
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
