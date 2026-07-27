import { lstatSync, readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import process from "node:process";

const allowedFiles = new Set(["coverage-final.json", "junit.xml", "lcov.info"]);
const forbiddenMarkers = [
  /sb_(?:secret|publishable)_/iu,
  /otpauth:/iu,
  /<system-(?:out|err)/iu,
  /<(?:failure|error)\b/iu,
  /authorization/iu,
  /bearer\s/iu,
  /correctoption/iu,
  /acceptedanswers/iu,
];

function fail(message) {
  process.stderr.write(message + "\n");
  process.exitCode = 1;
}

const reportDirectory = process.argv[2];

if (reportDirectory === undefined) {
  fail("A coverage report directory is required.");
} else {
  const absoluteDirectory = resolve(reportDirectory);
  const entries = readdirSync(absoluteDirectory, { withFileTypes: true });

  if (entries.length === 0) {
    fail("Sanitized test reports are missing.");
  } else {
    for (const entry of entries) {
      if (!entry.isFile() || !allowedFiles.has(entry.name)) {
        fail("Sanitized test reports contain an unexpected file.");
        break;
      }

      const path = resolve(absoluteDirectory, entry.name);

      if (lstatSync(path).isSymbolicLink()) {
        fail("Sanitized test reports must not contain symbolic links.");
        break;
      }

      const contents = readFileSync(path, "utf8");

      if (forbiddenMarkers.some((marker) => marker.test(contents))) {
        fail("Sanitized test reports contain forbidden output.");
        break;
      }
    }

    if (process.exitCode !== 1) {
      for (const expectedFile of allowedFiles) {
        if (!entries.some((entry) => entry.name === expectedFile)) {
          fail("Sanitized test reports are incomplete.");
          break;
        }
      }
    }

    if (process.exitCode !== 1) {
      process.stdout.write("Sanitized test reports verified.\n");
    }
  }
}
