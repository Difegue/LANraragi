import http from "k6/http";

// Run with: k6 run tools/k6/page_fetching.js

export const options = {
    scenarios: {
        cold_start: {
            executor: "shared-iterations",
            vus: 4,
            iterations: 20,
            startTime: "0s",
        },
        lukewarm_start: {
            executor: "shared-iterations",
            vus: 4,
            iterations: 10,
            startTime: "10s",
        },
    },
};

export function setup() {
    http.del("http://localhost:3000/api/tempfolder");

    const resp = http.get("http://localhost:3000/api/archives");

    return { archives: resp.json() };
}

export default function (data) {
    const { archives } = data;

    const inx = Math.floor(Math.random() * archives.length);
    const archive = archives[inx];

    const files = http.get(`http://localhost:3000/api/archives/${archive.arcid}/files`).json();

    for (const p of files.pages) {
        http.get(`http://localhost:3000${p}`);
    }
}
