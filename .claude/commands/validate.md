# Validate Implementation

You are validating a completed implementation against its plan.

## Instructions

1. **Load the plan and research**:
   - Read the plan from `thoughts/shared/plans/`
   - Read any related research from `thoughts/shared/research/`

2. **Systematic verification**:
   - Check each success criterion from the plan
   - Run all automated verification steps
   - Document manual verification results
   - Identify any deviations from the plan

3. **Generate validation report**:
   - Save to `thoughts/shared/plans/[feature]-validation-[date].md`

4. **Report format**:
```markdown
# Validation Report: [Feature Name]
Date: [YYYY-MM-DD]
Plan: [link to plan]
Implementation Date: [date implemented]

## Success Criteria Checklist
- [x] [Criterion 1] - PASS
- [ ] [Criterion 2] - FAIL: [reason]

## Automated Verification
Run these commands and record results:
```bash
make build  # Build verification
make test   # Test verification
```

| Check | Command | Status | Notes |
|-------|---------|--------|-------|
| Build | `make build` | PASS/FAIL | [exit code, errors] |
| Tests | `make test` | PASS/FAIL | [X/Y passed, failures] |

## Manual Verification
| Check | Status | Notes |
|-------|--------|-------|
| [UI check] | PASS/FAIL | [details] |

## Deviations from Plan
| Planned | Actual | Reason |
|---------|--------|--------|
| [expected] | [what happened] | [why] |

## Issues Found
1. [Issue description]
   - Severity: High/Medium/Low
   - Recommended fix: [approach]

## Overall Status
**[PASS/PASS WITH NOTES/FAIL]**

## Recommendations
- [Any follow-up work needed]
```

## Important
- Be thorough - check everything in the plan
- Document ALL deviations, even minor ones
- Clearly categorize issues by severity
- Provide actionable recommendations

Feature to validate: $ARGUMENTS
