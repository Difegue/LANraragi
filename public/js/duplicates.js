/**
 * Duplicate Operations.
 */
const Duplicates = {};

Duplicates.dt = {};


Duplicates.initializeAll = function () {
    // bind events to DOM
    $(document).on("click.goback", "#goback", () => { window.location.replace("./"); });
    $(document).on("mouseenter.thumbnail-wrapper", ".thumbnail-wrapper", (e) => $(e.currentTarget).find(".thumbnail-popover").show());
    $(document).on("mouseleave.thumbnail-wrapper", ".thumbnail-wrapper", (e) => $(e.currentTarget).find(".thumbnail-popover").hide());

    $(document).on("click.find-duplicates", ".find-duplicates", Duplicates.findDuplicates);
    $(document).on("click.clear-duplicates", ".clear-duplicates", () => { window.location.href = new LRR.apiURL("/duplicates?delete=1"); });
    $(document).on("click.delete-archive", ".delete-archive", Duplicates.deleteArchive);
    $(document).on("click.delete-selected", ".delete-selected", Duplicates.deleteArchives);

    if (localStorage.hasOwnProperty("dupeMinionJob")) {
        // If we are searching for duplicates, show the processing message
        $(".find-duplicates").hide();
        $("#processing").show();

        Duplicates.pollMinionJob(localStorage.dupeMinionJob);
    } 

    if (localStorage.hasOwnProperty("previousDupeJob")) {

        // Remove the previous job from localStorage
        localStorage.removeItem("previousDupeJob");

        // We had a previous job, show the "no duplicates" message if there's no dupe data on the page
        $("#nodupes").show();
    }

    $(document).on("change.duplicate-select-condition", ".duplicate-select-condition", Duplicates.conditionChange);
    Duplicates.initializeDataTable();
}

/**
 * Sends a POST request to queue a find_duplicates job,
 * detecting archive duplicates based on their thumbnail hashes.
 */
Duplicates.findDuplicates = function () {

    let formData = new FormData();
    formData.append("args", "[5]"); // threshold
    formData.append("priority", 0);

    $(".find-duplicates").hide();
    $("#processing").show();

    Server.callAPIBody(`/api/minion/find_duplicates/queue`, "POST", formData,
        "Queued up a job to find duplicates! Stay tuned for updates or check the Minion console.",
        I18N.MinionSendError,
        (data) => {
            // Disable the buttons to avoid accidental double-clicks.
            $(".find-duplicates").prop("disabled", true);
            localStorage.dupeMinionJob = data.job;

            Duplicates.pollMinionJob(data.job);
        },
    );
};

Duplicates.pollMinionJob = function (job) {
    // Check minion job state periodically while we're on this page
    Server.checkJobStatus(
        job,
        true,
        (d) => {
            // Refresh the window so that the newly found duplicates are shown.
            // Make sure the URL doesn't contain delete=1 so we don't instantly delete them.
            if (window.location.href.includes("delete=1")) {
                window.location.href = window.location.href.replace(/delete=1/, "");
            }
            else {
                // If the job is done, reload the page to show the results.
                localStorage.previousDupeJob = localStorage.dupeMinionJob;
                localStorage.removeItem("dupeMinionJob");
                window.location.reload();
            }
        },
        (error) => {
            $(".find-duplicates").prop("disabled", false);
            LRR.showErrorToast(I18N.MinionCheckError, error);
        },
    );
}

Duplicates.drawCallbackDataTable = function (settings) {
    var groupColumn = 0;
    var api = this.api();
    var rows = api.rows({ page: 'current' }).nodes();
    var lastGroup = null;

    // Iterate over the data once to insert group rows at end of each group
    api.column(groupColumn, { page: 'current' })
        .data()
        .each(function (group, i) {
            if (lastGroup && lastGroup !== group) {
                $(rows).eq(i).before(
                    '<tr class="separator"><td colspan="10" style="padding: 0px;"></td></tr>'
                );
            }
            lastGroup = group;
        });
}

Duplicates.initializeDataTable = function () {

    // Classes for even/odd lines
    $.fn.dataTableExt.oStdClasses.sStripeOdd = "gtr0";
    $.fn.dataTableExt.oStdClasses.sStripeEven = "gtr1";

    Duplicates.dt = $('#ds').DataTable({
        dom: '<"table-control-wrapper" <"search-box" f><"length-box" l>><t><p>',
        // avoid sorting columns as it messes with the grouping
        columns: [
            { title: 'Group-Key', visible: false },
            { title: '', orderable: false, width:"20px" },
            { title: 'Title', orderable: false},
            { title: 'Pages', orderable: false, width:"52px" },
            { title: 'Filename', orderable: false },
            { title: 'Filesize', orderable: false },
            { title: 'Date', orderable: false },
            { title: 'Tags', orderable: false },
            { title: 'Action', orderable: false }
        ],
        order: [[0, 'asc']],
        autoWidth: false,
        pageLength: 10,
        deferRender: true,
        drawCallback: Duplicates.drawCallbackDataTable
    });
};

Duplicates.compareDuplicates = function (rows, field, fieldType, order = 'desc') {
    var values = [];
    var rowToExclude = null;

    // Determine comparator and starting value based on order
    var comparator = order === 'asc' ? Math.min : Math.max;
    var targetValue = order === 'asc' ? Infinity : -Infinity;

    // Function to parse the value based on the field type
    function parseValue(value) {
        if (fieldType === 'integer') {
            return parseInt(value, 10);
        } else if (fieldType === 'float') {
            return parseFloat(value);
        } else if (fieldType === 'date') {
            return new Date(value).getTime();
        }
        return value;
    }
    // Iterate over rows to find the target row based on the comparator
    rows.each(function () {
        var row = $(this);
        var value = parseValue(row.find(`.${field}`).text());
        values.push(value);

        if (comparator(value, targetValue) === value) {
            targetValue = value;
            rowToExclude = row;
        }
    });

    // Do not check anything if all values are equal
    var allEqual = values.every((val) => val === values[0]);
    if (allEqual) return;

    // Iterate over rows again to check the checkbox for all rows except the target row
    rows.each(function () {
        var row = $(this);
        if (rowToExclude && row[0] !== rowToExclude[0]) {
            row.find('.form-check-input').prop('checked', true);
        }
    });
}

Duplicates.conditionChange = function (event) {
    var option = $(event.target).val();

    // Clear current selection
    $('.form-check-input').prop('checked', false);

    // Early return if none should be selected
    if (option === 'none') {
        return;
    }

    $('.duplicate-group').each((_, group) => {
        // Find all rows of a group
        var groupRow = $(group);
        var rowsInGroup = groupRow.add(groupRow.nextUntil('.separator'));

        // Compare rows in group according to selected option
        switch (option) {
            case 'less-tags':
                Duplicates.compareDuplicates(rowsInGroup, "tag-count", "integer");
                break;
            case 'less-size':
                Duplicates.compareDuplicates(rowsInGroup, "file-size", "float");
                break;
            case 'less-pages':
                Duplicates.compareDuplicates(rowsInGroup, "page-count", "integer");
                break;
            case 'not-old':
                Duplicates.compareDuplicates(rowsInGroup, "date-added", "date");
                break;
            case 'not-young':
                Duplicates.compareDuplicates(rowsInGroup, "date-added", "date", "asc");
                break;
        };
    });
};

Duplicates.deleteArchive = function (event) {
    LRR.showPopUp({
        text: I18N.ConfirmArchiveDeletion,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            archiveid = $(event.currentTarget).attr('data-id');
            Server.deleteArchive(archiveid, () => { Duplicates.dt.row($(event.currentTarget).parents('tr')).remove().draw()});
        }
    });
};

Duplicates.deleteArchives = function () {
    LRR.showPopUp({
        text: I18N.ConfirmArchivesDeletion,
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: I18N.ConfirmYes,
        reverseButtons: true,
        confirmButtonColor: "#d33",
    }).then((result) => {
        if (result.isConfirmed) {
            $("table tbody tr").each(function () {
                const row = $(this);
                const isChecked = row.find(".form-check-input").is(":checked");
                const dataId = row.find(".delete-archive").attr("data-id");

                if (isChecked && dataId) {
                    Server.deleteArchive(dataId, () => { Duplicates.dt.row(row).remove().draw() });
                }
            });
        }
    });
};

jQuery(() => {
    Duplicates.initializeAll();
});
