/**
 * Logs Operations.
 */
const Logs = {};

Logs.lastType = "";

Logs.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.refresh", "#refresh", Logs.refreshLog);
    $(document).on("click.loglines", "#loglines", Logs.refreshLog);
    $(document).on("click.show_general", "#show_general", () => Logs.showLog("general"));
    $(document).on("click.show_shinobu", "#show_shinobu", () => Logs.showLog("shinobu"));
    $(document).on("click.show_plugins", "#show_plugins", () => Logs.showLog("plugins"));
    $(document).on("click.show_mojo", "#show_mojo", () => Logs.showLog("mojo"));
    $(document).on("click.show_redis", "#show_redis", () => Logs.showLog("redis"));
    $(document).on("click.return", "#return", () => { window.location.replace("/"); });

    Logs.showLog("general");
};

Logs.showLog = function (type) {
    $.get(`/logs/${type}?lines=${$("#loglines").val()}`, (data) => {
        $("#log-container").html(LRR.encodeHTML(data));
        $("#indicator").html(type);
        $("#log-container").scrollTop($("#log-container").prop("scrollHeight"));
    });

    Logs.lastType = type;
};

Logs.refreshLog = function () {
    Logs.showLog(Logs.lastType);
};

jQuery(() => {
    Logs.initializeAll();
});

window.Logs = Logs;
