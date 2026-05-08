#!/usr/bin/env node
/**
 * OCR one image with system tesseract CLI (pure JS wrapper, no npm deps).
 *
 * Usage:
 *   node ocr-image.mjs <image-path> [langs]
 * Example:
 *   node ocr-image.mjs ./img1.jpg chi_sim+eng
 */
import fs from "fs";
import { spawn } from "child_process";

function runOcr(imagePath, langs) {
  return new Promise((resolve, reject) => {
    const proc = spawn("tesseract", [imagePath, "stdout", "-l", langs], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (d) => {
      stdout += String(d);
    });
    proc.stderr.on("data", (d) => {
      stderr += String(d);
    });
    proc.on("error", (err) => {
      if (err?.code === "ENOENT") {
        reject(
          new Error(
            "tesseract CLI not found. Install it first, then retry."
          )
        );
        return;
      }
      reject(err);
    });
    proc.on("close", (code) => {
      if (code === 0) {
        resolve(stdout);
        return;
      }
      reject(new Error(stderr || `tesseract exited with code ${code}`));
    });
  });
}

async function main() {
  const imagePath = process.argv[2];
  const langs = process.argv[3] || "chi_sim+eng";
  if (!imagePath) {
    console.error("Usage: node ocr-image.mjs <image-path> [langs]");
    process.exit(1);
  }
  if (!fs.existsSync(imagePath)) {
    console.error("File not found:", imagePath);
    process.exit(1);
  }

  const text = await runOcr(imagePath, langs);
  process.stdout.write(text);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
