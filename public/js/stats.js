/**
 * Stats Operations
 */
import * as Server from "./mod/server.js";
import * as LRR from "./mod/common.js";
import I18N from "i18n";

const Stats = {};

Stats.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.goback", "#goback", () => { window.location.replace("./"); });

    Server.callAPI("/api/database/stats?minweight=2&hide_excluded_namespaces=true", "GET", null, I18N.TagStatsLoadFailure,
        (data) => {
            $("#statsLoading").hide();
            $("#tagcount").html(data.length);
            $("#tagCloud").jQCloud(data, {
                autoResize: true,
            });

            // Sort data by weight
            data.sort((a, b) => b.weight - a.weight);

            // Buildup detailed stats
            const tagList = $("#tagList");
            data.forEach((tag) => {
                const namespacedTag = LRR.buildNamespacedTag(tag.namespace, tag.text);
                const url = `${LRR.getTagSearchURL(tag.namespace, tag.text)}`;
                const encodedNamespacedTag = LRR.encodeHTML(namespacedTag);

                const ocss = "max-width: 95%; display: flex;";
                const icss = "text-overflow: ellipsis; white-space: nowrap; overflow: hidden; min-width: 0; max-width: 100%;";

                const html = `<a href="${LRR.encodeHTML(url)}" title="${encodedNamespacedTag}" class="${LRR.encodeHTML(tag.namespace)}-tag" style="${ocss}"><span style="${icss}">${encodedNamespacedTag}</span>&nbsp;<b>(${tag.weight})</b>`;
                tagList.append(html);
            });

            $("#detailedStats").show();
        },
    );
};

jQuery(() => {
    Stats.initializeAll();
});
