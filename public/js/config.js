/**
 * Config Operations.
 */
const Config = {};

Config.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.save", "#save", () => { Server.saveFormData("#editConfigForm"); });
    $(document).on("click.plugin-config", "#plugin-config", () => { window.location.href = new LRR.apiURL("/config/plugins"); });
    $(document).on("click.backup", "#backup", () => { window.location.href = new LRR.apiURL("/backup"); });
    $(document).on("click.return", "#return", () => { window.location.href = new LRR.apiURL("/"); });
    $(document).on("click.enablepass", "#enablepass", Config.enable_pass);
    $(document).on("click.enableresize", "#enableresize", Config.enable_resize);
    $(document).on("click.usedateadded", "#usedateadded", Config.enable_timemodified);

    $(document).on("click.rescan-button", "#rescan-button", Config.rescanContentFolder);
    $(document).on("click.clean-temp", "#clean-temp", Server.cleanTemporaryFolder);
    $(document).on("click.reset-search-cache", "#reset-search-cache", Server.invalidateCache);
    $(document).on("click.clear-new-tags", "#clear-new-tags", Server.clearAllNewFlags);

    $(document).on("click.clean-db", "#clean-db", Server.cleanDatabase);
    $(document).on("click.drop-db", "#drop-db", Server.dropDatabase);

    $(document).on("click.restart-button", "#restart-button", Config.rebootShinobu);
    $(document).on("click.open-minion", "#open-minion", () => LRR.openInNewTab(new LRR.apiURL("/minion")));

    $(document).on("click.genthumb-button", "#genthumb-button", () => Server.regenerateThumbnails(false));
    $(document).on("click.forcethumb-button", "#forcethumb-button", () => Server.regenerateThumbnails(true));

    $(document).on("click.modern", "#modern", () => Config.switch_style("Hachikuji"));
    $(document).on("click.modern-div", "#modern-div", () => Config.switch_style("Hachikuji"));

    $(document).on("click.modern_clear", "#modern_clear", () => Config.switch_style("Yotsugi"));
    $(document).on("click.modern-clear-div", "#modern-clear-div", () => Config.switch_style("Yotsugi"));

    $(document).on("click.modern_red", "#modern_red", () => Config.switch_style("Nadeko"));
    $(document).on("click.modern-red-div", "#modern-red-div", () => Config.switch_style("Nadeko"));

    $(document).on("click.ex", "#ex", () => Config.switch_style("Sad Panda"));
    $(document).on("click.ex-div", "#ex-div", () => Config.switch_style("Sad Panda"));

    $(document).on("click.g", "#g", () => Config.switch_style("H-Verse"));
    $(document).on("click.g-div", "#g-div", () => Config.switch_style("H-Verse"));

    Config.enable_pass();
    Config.enable_resize();
    Config.enable_timemodified();
    Config.shinobuStatus();
    setInterval(Config.shinobuStatus, 5000);
};

Config.rebootShinobu = function () {
    $("#restart-button").prop("disabled", true);
    Server.callAPI("/api/shinobu/restart", "POST", "Background Worker restarted!", "Error while restarting Worker:",
        () => {
            $("#restart-button").prop("disabled", false);
            Config.shinobuStatus();
        },
    );
};

Config.rescanContentFolder = function () {
    $("#rescan-button").prop("disabled", true);
    Server.callAPI("/api/shinobu/rescan", "POST", "Content folder rescan started!", "Error while restarting Worker:",
        () => {
            $("#rescan-button").prop("disabled", false);
            Config.shinobuStatus();
        },
    );
};

// Update the status of the background worker.
Config.shinobuStatus = function () {
    Server.callAPI("/api/shinobu", "GET", null, "Error while querying Shinobu status:",
        (data) => {
            if (data.is_alive) {
                $("#shinobu-ok").show();
                $("#shinobu-ko").hide();
            } else {
                $("#shinobu-ko").show();
                $("#shinobu-ok").hide();
            }
            $("#pid").html(data.pid);
        },
    );
};

Config.switch_style = function (cssTitle) {
    let i, linkTag, correctStyle, defaultStyle, newStyle;
    correctStyle = 0;

    for (i = 0, linkTag = document.getElementsByTagName("link"); i < linkTag.length; i++) {
        if ((linkTag[i].rel.indexOf("stylesheet") !== -1) && linkTag[i].title) {
            if ((linkTag[i].rel.indexOf("alternate stylesheet") !== -1)) linkTag[i].disabled = true;
            else defaultStyle = linkTag[i];

            if (linkTag[i].title === cssTitle) {
                newStyle = linkTag[i];
                correctStyle = 1;
            }
        }
    }

    if (correctStyle === 1) { // if the style that was switched to exists
        defaultStyle.disabled = true; // we disable the default style
        newStyle.disabled = false; // we enable the new style
    }
};

Config.enable_pass = function () {
    if ($("#enablepass").prop("checked")) $(".passwordfields").show();
    else $(".passwordfields").hide();
};

Config.enable_resize = function () {
    if ($("#enableresize").prop("checked")) $(".resizefields").show();
    else $(".resizefields").hide();
};

Config.enable_timemodified = function () {
    if ($("#usedateadded").prop("checked")) $(".datemodified").show();
    else $(".datemodified").hide();
};

jQuery(() => {
    Config.initializeAll();
});
