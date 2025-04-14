import http from "k6/http";
import { sleep } from "k6";

/**
 * Fetches up to 20 pages from the first archive, ensuring the cache is cold.
 *
 * HOWEVER, it does not delete any existing thumbnails from thumbs/ so you need to do that if
 * needed.
 *
 * k6 run tools/k6/covers_cold.js
 */
const ParallelThumbnails = 6;
const MaxThumbnails = 100;
const BaseUrl = "http://localhost:3000";

export const options = {
    vus: 1,
    iterations: 1,
};

function arrayChunk(arr, size) {
    return arr.reduce((acc, _, i) => {
        if (i % size === 0) acc.push(arr.slice(i, i + size));
        return acc;
    }, []);
}

function awaitJobs(jobs) {
    const urls = jobs.map((job) => `${BaseUrl}/api/minion/${job}`);

    for (;;) {
        const ret = http.batch(urls).filter((x) => x.json().state !== "finished");
        if (ret.length === 0) {
            break;
        }
        sleep(0.5);
    }
}

export function setup() {
    const resp = http.get(`${BaseUrl}/api/archives`).json();
    return { archives: resp };
}

export default function (data) {
    const { archives } = data;

    http.del(`${BaseUrl}/api/tempfolder`);
    for (const chunk of arrayChunk(archives.slice(0, MaxThumbnails), ParallelThumbnails)) {
        const thumbnails = chunk.map((archive) => `${BaseUrl}/api/archives/${archive.arcid}/thumbnail?no_fallback=true`);

        // If the thumbnail is not available yet, wait for creation
        const resp = http.batch(thumbnails);
        const jobs = resp.filter((x) => x.status === 202).map((x) => x.json().job);
        awaitJobs(jobs);
    }
}
