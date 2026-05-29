#!/usr/bin/env python3
"""Validate prd.json format for Ralph Hermes skill."""

import json
import sys
from pathlib import Path

def validate_prd(prd_path: str) -> bool:
    """Validate a prd.json file.
    
    Returns True if valid, False otherwise.
    """
    path = Path(prd_path)
    if not path.exists():
        print(f"ERROR: File not found: {prd_path}")
        return False
    
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}")
        return False
    
    # Check required top-level fields
    required = ["project", "branchName", "description", "userStories"]
    for field in required:
        if field not in data:
            print(f"ERROR: Missing required field: {field}")
            return False
    
    # Check userStories is a list
    if not isinstance(data["userStories"], list):
        print("ERROR: userStories must be a list")
        return False
    
    if len(data["userStories"]) == 0:
        print("ERROR: userStories is empty")
        return False
    
    # Check each story has required fields
    for i, story in enumerate(data["userStories"]):
        story_id = story.get("id", f"index {i}")
        for field in ["id", "title", "description", "acceptanceCriteria", "priority", "passes", "notes"]:
            if field not in story:
                print(f"ERROR: Story {story_id} missing field: {field}")
                return False
        
        # Check acceptanceCriteria is a list
        if not isinstance(story["acceptanceCriteria"], list):
            print(f"ERROR: Story {story_id} acceptanceCriteria must be a list")
            return False
        
        # Must have "Typecheck passes"
        has_typecheck = any("Typecheck passes" in ac for ac in story["acceptanceCriteria"])
        if not has_typecheck:
            print(f"WARNING: Story {story_id} missing 'Typecheck passes' in acceptanceCriteria")
        
        # Check passes is boolean
        if story["passes"] not in [True, False]:
            print(f"ERROR: Story {story_id} passes must be boolean, got: {story['passes']}")
            return False
    
    # Check branchName starts with "ralph/"
    if not data["branchName"].startswith("ralph/"):
        print(f"WARNING: branchName should start with 'ralph/', got: {data['branchName']}")
    
    print(f"✓ prd.json valid: {data['project']} — {len(data['userStories'])} stories")
    print(f"  Branch: {data['branchName']}")
    passed = sum(1 for s in data["userStories"] if s["passes"])
    print(f"  Progress: {passed}/{len(data['userStories'])} completed")
    return True


if __name__ == "__main__":
    prd_path = sys.argv[1] if len(sys.argv) > 1 else "./ralph/prd.json"
    result = validate_prd(prd_path)
    sys.exit(0 if result else 1)