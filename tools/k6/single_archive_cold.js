import http from "k6/http";

/**
 * Fetches up to 20 pages from the first archive, ensuring the cache is cold.
 *
 * k6 run tools/k6/single_archive_cold.js
 */

export const options = {
    vus: 1,
    iterations: 4,
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
    const resp = http.get("http://localhost:3000/api/archives").json();
    const archive = resp[0];

    return { archive: archive };
}

export default function (data) {
    const { archive } = data;

    http.del("http://localhost:3000/api/tempfolder");
    fetchAllPages(archive);
}
