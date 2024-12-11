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

    $(document).on("click.find-duplicates", ".find-duplicates", Server.findDuplicates);
    $(document).on("click.clear-duplicates", ".clear-duplicates", () => { window.location.href = new LRR.apiURL("/duplicates?delete=1"); });
    $(document).on("click.delete-archive", ".delete-archive", Duplicates.deleteArchive);
    $(document).on("click.delete-selected", ".delete-selected", Duplicates.deleteArchives);

    $(document).on("change.duplicate-select-condition", ".duplicate-select-condition", Duplicates.conditionChange);
    Duplicates.inizializeDataTable();
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

Duplicates.inizializeDataTable = function () {
    Duplicates.dt = $('#ds').DataTable({
        dom: '<"table-control-wrapper" <"search-box" f><"length-box" l>><t><p>',
        // avoid sorting columns as it messes with the grouping
        columns: [
            { title: 'Group-Key', visible: false },
            { title: '', orderable: false },
            { title: '', orderable: false },
            { title: 'Title', orderable: false },
            { title: 'Pages', orderable: false },
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
        text: "Are you sure you want to delete this archive?",
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: "Yes, delete it!",
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
        text: "Are you sure you want to delete all selected archives?",
        icon: "warning",
        showCancelButton: true,
        focusConfirm: false,
        confirmButtonText: "Yes, delete all!",
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
