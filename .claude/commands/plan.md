# Create Implementation Plan

You are creating a detailed implementation plan. DO NOT write any code during this phase.

## Instructions

1. **Read the research first** (if available):
   - Check `thoughts/shared/research/` for relevant research documents
   - If no research exists, consider running `/research` first

2. **Create a comprehensive plan** through multiple iterations:
   - Start with a high-level approach
   - Refine with specific implementation details
   - Use "think hard" or "ultrathink" for complex decisions
   - Aim for ~5 iterations of refinement

3. **Plan must include**:
   - Exact file paths to create/modify
   - Code snippets or pseudocode for key changes
   - Order of operations (what to implement first)
   - Success criteria (how to know it's done)
   - Verification steps:
     - **Automated**: Tests, linting, type checks
     - **Manual**: UI checks, UX validation, performance testing

4. **Save the plan** to `thoughts/shared/plans/[feature]-[date].md`

5. **Plan format**:
```markdown
# Plan: [Feature Name]
Date: [YYYY-MM-DD]
Research: [link to research doc if applicable]

## Overview
[What we're building and why]

## Implementation Phases

### Phase 1: [Name]
**Files:**
- `path/to/file.swift` - [what changes]

**Changes:**
[Specific code changes or pseudocode]

**Verification:**
- [ ] Automated: [test/lint commands]
- [ ] Manual: [what to check]

### Phase 2: [Name]
[...]

## Success Criteria
- [ ] [Specific, measurable outcome]

## Risks & Mitigations
- Risk: [description] → Mitigation: [approach]
```

## Important
- This is PLANNING ONLY - no code changes
- Be specific about file paths and code changes
- Include both automated and manual verification steps
- After plan is approved, use `/clear` before implementing

User request: $ARGUMENTS
