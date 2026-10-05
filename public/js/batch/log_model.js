import { createModel, signal } from "@preact/signals";

export const LogModel = createModel(() => {
    const rows = signal([]);
    const MAX_LENGTH = 100000;
    return {
        rows,
        addRow(row) {
            rows.value.push(row);
            // May keep browsers from committing sudoku in huge batches?
            if (rows.value.length > MAX_LENGTH) {
                rows.value.shift();
            }
        },
        clear() {
            rows.value = [];
        },
    };
});
