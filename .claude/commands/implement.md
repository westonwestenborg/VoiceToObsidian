# Implement Plan

You are implementing a plan. Execute ONE PHASE at a time, then pause for verification.

## Instructions

1. **Load the plan**:
   - Read the plan from `thoughts/shared/plans/[feature]-[date].md`
   - If no plan specified, list available plans and ask which to implement

2. **Execute phases sequentially**:
   - Implement ONE phase at a time
   - After each phase, STOP and report:
     - What was implemented
     - Automated verification results (tests, lint)
     - What manual verification the user should perform
   - Wait for user confirmation before proceeding to next phase

3. **During implementation**:
   - Follow existing code patterns and conventions
   - Update the plan document if you discover new requirements
   - Note any deviations from the plan and why

4. **After each phase, report**:
```markdown
## Phase [N] Complete: [Name]

### Changes Made
- `path/to/file.swift:123` - [description]

### Automated Verification
- [ ] Tests: [pass/fail]
- [ ] Lint: [pass/fail]
- [ ] Build: [pass/fail]

### Manual Verification Needed
- [ ] [What the user should check]

### Deviations from Plan
- [Any changes made vs. original plan]

Ready to proceed to Phase [N+1]? (y/n)
```

## Important
- ONE PHASE AT A TIME - do not proceed without user confirmation
- Manual testing catches UX/performance issues automated tests miss
- Update the plan document with any discoveries
- If blocked, document the issue and ask for guidance

Plan to implement: $ARGUMENTS
