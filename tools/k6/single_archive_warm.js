import http from "k6/http";

/**
 * Fetches up to 20 pages from the first archive, ensuring the cache is warm first.
 *
 * k6 run tools/k6/single_archive_warm.js
 */

export const options = {
    vus: 10,
    iterations: 50,
};

function fetchAllPages(archive) {
    const files = http.get(`http://localhost:3000/api/archives/${archive.arcid}/files`).json();

    let left = 10;
    for (const p of files.pages) {
        http.get(`http://localhost:3000${p}`);
        left -= 1;
        if (left === 0) {
            break;
        }
    }
}

export function setup() {
    http.del("http://localhost:3000/api/tempfolder");

    const resp = http.get("http://localhost:3000/api/archives").json();
    const archive = resp[0];
    fetchAllPages(archive);

    return { archive: archive };
}

export default function (data) {
    const { archive } = data;

    fetchAllPages(archive);
}
