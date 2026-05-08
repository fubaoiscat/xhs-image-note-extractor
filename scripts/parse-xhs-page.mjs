#!/usr/bin/env node
/**
 * Parse Xiaohongshu explore H5 HTML: extract __INITIAL_STATE__ note payload.
 * Usage: node parse-xhs-page.mjs <file.html>
 *        curl -sL -A "Mozilla/5.0 (iPhone ...)" "<url>" | node parse-xhs-page.mjs -
 *
 * Prints JSON: { title, desc, type, noteId, images: [{ index, url }] }
 * Exits 1 if state missing or note payload empty.
 */
import fs from "fs";

function readInput(path) {
  if (path === "-") return fs.readFileSync(0, "utf8");
  return fs.readFileSync(path, "utf8");
}

function stripUndefinedLikeJson(js) {
  return js
    .replace(/:undefined(?=[,}\]])/g, ":null")
    .replace(/,undefined(?=[,}\]])/g, ",null");
}

function extractInitialStateJson(html) {
  const key = "window.__INITIAL_STATE__=";
  const i = html.indexOf(key);
  if (i === -1) return null;
  const start = i + key.length;
  const end = html.indexOf("</script>", start);
  if (end === -1) return null;
  return html.slice(start, end);
}

function main() {
  const path = process.argv[2];
  if (!path) {
    console.error("Usage: node parse-xhs-page.mjs <file.html|-");
    process.exit(1);
  }
  const html = readInput(path);
  const raw = extractInitialStateJson(html);
  if (!raw) {
    console.error("No window.__INITIAL_STATE__ found.");
    process.exit(1);
  }
  let state;
  try {
    state = JSON.parse(stripUndefinedLikeJson(raw));
  } catch (e) {
    console.error("JSON parse failed:", e.message);
    process.exit(1);
  }

  const note = state?.noteData?.data?.noteData;
  if (!note || typeof note !== "object") {
    console.error("noteData.data.noteData missing or empty (need share URL with xsec_token?).");
    process.exit(1);
  }

  const imageList = Array.isArray(note.imageList) ? note.imageList : [];
  const images = imageList.map((im, idx) => {
    let url = im?.url;
    if (!url && Array.isArray(im?.infoList)) {
      const dtl = im.infoList.find((x) => x?.imageScene === "H5_DTL");
      url = dtl?.url || im.infoList[0]?.url;
    }
    if (url && url.startsWith("http://")) url = "https://" + url.slice("http://".length);
    return { index: idx + 1, url };
  });

  const out = {
    title: note.title ?? null,
    desc: note.desc ?? null,
    type: note.type ?? null,
    noteId: note.noteId ?? null,
    imageCount: images.length,
    images,
  };
  console.log(JSON.stringify(out, null, 2));
}

main();
