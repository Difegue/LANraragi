/**
 * Stats Operations.
 */
const Stats = {};

Stats.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.goback", "#goback", () => { window.location.replace("./"); });

    Server.callAPI("/api/database/stats?minweight=2", "GET", null, "Couldn't load tag statistics",
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
                // Ignore tags that start with "source:" or "date_added:"
                if (tag.namespace === 'source' || tag.namespace === 'date_added')
                    return;
                const namespacedTag = LRR.buildNamespacedTag(tag.namespace, tag.text);
                const url = LRR.getTagSearchURL(tag.namespace, tag.text);

                const ocss = "max-width: 95%; display: flex;";
                const icss = "text-overflow: ellipsis; white-space: nowrap; overflow: hidden; min-width: 0; max-width: 100%;";

                const html = `<a href="${url}" title="${namespacedTag}" class="${tag.namespace}-tag" style="${ocss}"><span style="${icss}">${namespacedTag}</span>&nbsp;<b>(${tag.weight})</b>`;
                tagList.append(html);
            });

            $("#detailedStats").show();
        },
    );
};

jQuery(() => {
    Stats.initializeAll();
});
