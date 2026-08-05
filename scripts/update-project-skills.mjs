#!/usr/bin/env node

import { existsSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const dotfilesDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const configDir = join(dotfilesDir, ".config");
const lockPath = join(configDir, "skills-lock.json");
const npx = process.platform === "win32" ? "npx.cmd" : "npx";
const ansiEscapePattern = /\x1b\[[0-?]*[ -/]*[@-~]/g;

function reportFailedSkills(output) {
    const plainOutput = output.replace(ansiEscapePattern, "");
    const failedSkills = [...plainOutput.matchAll(/Failed to update ([^\r\n]+)/g)]
        .map((match) => match[1].trim())
        .filter((skill) => !/^\d+ skill\(s\)$/.test(skill))
        .filter((skill, index, skills) => skills.indexOf(skill) === index);

    if (failedSkills.length === 0) {
        return;
    }

    console.error("\nSkills that failed to update:");
    for (const skill of failedSkills) {
        console.error(`  - ${skill}`);
    }
}

async function main() {
    if (!existsSync(lockPath)) {
        throw new Error(`Skills lock file not found: ${lockPath}`);
    }

    const tempDir = await mkdtemp(join(tmpdir(), "dotfiles-skills-"));
    try {
        const update = spawnSync(npx, ["skills", "update", "--project", "--yes"], {
            cwd: configDir,
            encoding: "utf8",
            env: {
                ...process.env,
                CLAUDE_CONFIG_DIR: join(tempDir, "disabled-claude"),
            },
            shell: false,
        });

        if (update.stdout) {
            process.stdout.write(update.stdout);
        }
        if (update.stderr) {
            process.stderr.write(update.stderr);
        }
        if (update.error) {
            throw update.error;
        }

        reportFailedSkills(`${update.stdout ?? ""}\n${update.stderr ?? ""}`);
        if (update.status !== 0) {
            process.exitCode = update.status ?? 1;
        }
    } finally {
        await rm(tempDir, { recursive: true, force: true });
    }
}

main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
