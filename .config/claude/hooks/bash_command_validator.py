#!/usr/bin/env python3
"""
Claude Code Hook: Bash Command Validator
This hook runs as a PreToolUse hook for the Bash tool.
It validates bash commands against a set of rules before execution.
"""

import json
import re
import sys

_VALIDATION_RULES = [
    (
        r"^grep\b(?!.*\|)",
        "Use 'rg' (ripgrep) instead of 'grep' for better performance and features"
    ),
    (
        r"^find\s+\S+\s+-name\b",
        "Use 'rg --files | rg pattern' or 'rg --files -g pattern' instead of 'find -name' for better performance"
    ),
]

def _validate_command(command: str) -> list[str]:
    issues = []
    for pattern, message in _VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    if not command:
        sys.exit(0)

    issues = _validate_command(command)
    if issues:
        for message in issues:
            print(f"• {message}", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()