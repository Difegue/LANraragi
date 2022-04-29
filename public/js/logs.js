/**
 * Logs Operations.
 */
const Logs = {};

Logs.lastType = "";

Logs.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.refresh", "#refresh", Logs.refreshLog);
    $(document).on("click.loglines", "#loglines", Logs.refreshLog);
    $(document).on("click.show-general", "#show-general", () => Logs.showLog("general"));
    $(document).on("click.show-shinobu", "#show-shinobu", () => Logs.showLog("shinobu"));
    $(document).on("click.show-plugins", "#show-plugins", () => Logs.showLog("plugins"));
    $(document).on("click.show-mojo", "#show-mojo", () => Logs.showLog("mojo"));
    $(document).on("click.show-redis", "#show-redis", () => Logs.showLog("redis"));
    $(document).on("click.return", "#return", () => { window.location.href = "/"; });

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
