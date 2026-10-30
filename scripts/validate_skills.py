#!/usr/bin/env python3
"""Validate skills/*/SKILL.md against the Agent Skills format rules.

Rules (platform.claude.com/docs/en/agents-and-tools/agent-skills/overview):
- SKILL.md starts with YAML frontmatter containing `name` and `description`.
- name: <= 64 chars, lowercase letters, digits and hyphens, no "anthropic"/"claude".
- description: non-empty, <= 1024 chars, no XML tags.
Project rules: name matches the directory, referenced local files exist,
body stays well under the recommended size.
"""
import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9-]{1,64}$")
XML_RE = re.compile(r"<[^>]+>")
LINK_RE = re.compile(r"`(references/[^`]+)`")
MAX_BODY_WORDS = 3000


def parse_frontmatter(text):
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    fields = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields, text[end + 5:]


def validate(skill_dir):
    errors = []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [f"{skill_dir.name}: missing SKILL.md"]
    fields, body = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
    if fields is None:
        return [f"{skill_dir.name}: missing YAML frontmatter"]

    name = fields.get("name", "")
    if not NAME_RE.match(name):
        errors.append(f"{skill_dir.name}: invalid name {name!r}")
    if "anthropic" in name or "claude" in name:
        errors.append(f"{skill_dir.name}: name uses a reserved word")
    if name != skill_dir.name:
        errors.append(f"{skill_dir.name}: name {name!r} does not match directory")

    description = fields.get("description", "")
    if not description:
        errors.append(f"{skill_dir.name}: empty description")
    if len(description) > 1024:
        errors.append(f"{skill_dir.name}: description is {len(description)} chars (max 1024)")
    if XML_RE.search(description):
        errors.append(f"{skill_dir.name}: description contains XML tags")

    if len(body.split()) > MAX_BODY_WORDS:
        errors.append(f"{skill_dir.name}: body exceeds {MAX_BODY_WORDS} words")
    for ref in LINK_RE.findall(body):
        if not (skill_dir / ref).is_file():
            errors.append(f"{skill_dir.name}: referenced file {ref} not found")
    return errors


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "skills")
    skill_dirs = sorted(p for p in root.iterdir() if p.is_dir())
    if not skill_dirs:
        print(f"no skills found in {root}")
        return 1
    errors = [e for d in skill_dirs for e in validate(d)]
    for error in errors:
        print(f"ERROR {error}")
    print(f"{len(skill_dirs)} skills checked, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
