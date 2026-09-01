import { batch, computed, createModel, signal } from "@preact/signals";
import * as Server from "../mod/server.js";
import I18N from "i18n";

/**
 * @typedef Archive
 * @property {string} arcid
 * @property {boolean} isnew
 * @property {string} title
 */

export const ArchiveListModel = createModel((initialArchives = []) => {
    const archives = signal(/** @type Array<Archive>*/initialArchives);
    const checkedArchiveIds = signal(/** @type Set<string>*/new Set());
    const anyArchives = computed(() => {
        return archives.value.length > 0;
    });
    const loading = signal(false);

    // A bit ugly, but any top-level methods become untracked which prevents reactivity
    const isChecked = computed(() =>
        (arcid) => checkedArchiveIds.value.has(arcid)
    );

    function parseMetadataResponse(archives) {
        return archives.map(x => {
            return {
                ...x,
                // Data normalization, we don't need to suffer stringly booleans!
                isnew: x.isnew === "true",
            };
        });
    }

    return {
        archives,
        checkedArchiveIds,
        anyArchives,
        loading,
        isChecked,
        /**
         * @param {string} arcid
         */
        check(arcid) {
            const nextIds = new Set(this.checkedArchiveIds.value);
            nextIds.add(arcid);
            this.checkedArchiveIds.value = nextIds;
        },
        /**
         * @param {string} arcid
         */
        uncheck(arcid) {
            const nextIds = new Set(this.checkedArchiveIds.value);
            nextIds.delete(arcid);
            this.checkedArchiveIds.value = nextIds;
        },
        toggleCheckAll() {
            const all = new Set(this.archives.value.map(a => a.arcid));
            const checked = this.checkedArchiveIds.value;
            if (all.size > 0 && all.size === checked.size) {
                this.checkedArchiveIds.value = new Set();
            } else {
                this.checkedArchiveIds.value = all;
            }
        },
        /**
         * @param {Array<string>} ids
         */
        async loadSelectionOnly(ids) {
            this.loading.value = true;
            this.archives.value = [];

            const tankIds = ids.filter((id) => id.startsWith("TANK_"));
            const archiveIds = ids.filter((id) => !id.startsWith("TANK_"));

            // Expand tankoubons into their constituent archive IDs
            const tankFetches = tankIds.map((id) =>
                Server.callAPIAsync(`/api/tankoubons/${id}`, "GET", null, null)
                    .then((data) => {
                        if (data && data.archives) {
                            archiveIds.push(...data.archives);
                        }
                    }),
            );

            await Promise.all(tankFetches);

            // Deduplicate archive IDs
            const archiveIdSet = new Set(archiveIds);
            const uniqueIds = [...archiveIdSet];

            // Fetch metadata for each archive
            const archives = await Promise.all(uniqueIds.map((id) =>
                Server.callAPIAsync(`/api/archives/${id}/metadata`, "GET", null, null)
            ));

            batch(() => {
                this.archives.value = parseMetadataResponse(archives);
                this.checkedArchiveIds.value = archiveIdSet;
                this.loading.value = false;
            });
        },
        async loadArchives() {
            this.loading.value = true;
            this.archives.value = [];
            const [archives, untagged] = await Promise.all([
                Server.callAPIAsync("/api/archives", "GET", null, I18N.ArchiveListLoadFailure),
                Server.callAPIAsync("/api/archives/untagged", "GET", null, I18N.UntaggedLoadFailure),
            ]);

            if (archives !== null) {
                const untaggedSet = new Set(untagged);
                const parsed = parseMetadataResponse(archives);
                parsed.sort((a) => untaggedSet.has(a.arcid) ? -1 : 1);

                batch(() => {
                    this.archives.value = parsed;
                    this.loading.value = false;
                    this.checkedArchiveIds.value = untaggedSet;
                });
            }
        }
    };
});
