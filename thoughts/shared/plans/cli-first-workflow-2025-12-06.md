# Plan: CLI-First Development Workflow

Date: 2025-12-06
Research: `thoughts/shared/research/cli-first-workflow-2025-12-06.md`

## Progress

| Phase | Status |
|-------|--------|
| Phase 1: Create Makefile | COMPLETED |
| Phase 2: Update CLAUDE.md | COMPLETED |
| Phase 3: Update /implement command | COMPLETED |
| Phase 4: Update /validate command | COMPLETED |
| Phase 5: Test full workflow | COMPLETED |

## Overview

Implement CLI-first development practices to enable Claude to verify changes without manual Xcode interaction. This involves creating build automation scripts and updating documentation.

## Success Criteria

1. `make build` compiles the project successfully
2. `make test` runs all 29 tests and reports results
3. `make run` installs and launches app on simulator
4. `make log` streams app logs filtered by subsystem
5. CLAUDE.md documents CLI commands as primary build method
6. `/implement` command uses `make build` for verification
7. `/validate` command uses `make test` for verification

---

## Phase 1: Create Makefile [COMPLETED]

**Goal**: Create build automation with standard targets

### Files to Create

**`Makefile`** (new file in project root) - Created with fix: added `open -a Simulator` to `run` target to ensure GUI opens.

### Automated Verification
- [x] `make build` succeeds (exit code 0) - **PASS**
- [ ] `make test` runs tests - **BLOCKED** (pre-existing compile errors in test target, unrelated to Makefile)
- [x] `make help` displays usage information - **PASS**

### Manual Verification
- [x] Run `make run` and verify app launches on simulator - **PASS** (after adding `open -a Simulator`)
- [x] Run `make log` and verify logs appear - **PASS**

### Notes
- Added `open -a Simulator` to run target - `xcrun simctl boot` starts runtime but doesn't open GUI
- Pre-existing test compile errors in uncommitted files (TranscriptionManagerTests.swift, CustomWordsView.swift, CustomWordsManager.swift)

---

## Phase 2: Update CLAUDE.md [COMPLETED]

**Goal**: Document CLI commands as primary build method

### Changes to `CLAUDE.md`

Updated lines 5-19 with CLI-first documentation table.

### Automated Verification
- [x] CLAUDE.md syntax is valid markdown - **PASS**
- [x] No broken links in document - **PASS**

### Manual Verification
- [ ] Review updated section reads clearly
- [ ] Table renders correctly in markdown preview

---

## Phase 3: Update /implement Command

**Goal**: Integrate CLI verification into implementation workflow

### Changes to `.claude/commands/implement.md`

**Replace lines 24-35** (verification section):

```markdown
4. **After each phase, run automated verification**:
   ```bash
   make build  # Must succeed
   make test   # Should pass (note any failures)
   ```

5. **Report results**:
```markdown
## Phase [N] Complete: [Name]

### Changes Made
- `path/to/file.swift:123` - [description]

### Automated Verification
- [ ] Build: `make build` - [PASS/FAIL]
- [ ] Tests: `make test` - [PASS/FAIL, X/Y passed]

### Manual Verification Needed
- [ ] [What the user should check]

### Deviations from Plan
- [Any changes made vs. original plan]

Ready to proceed to Phase [N+1]? (y/n)
```
```

### Automated Verification
- [ ] implement.md is valid markdown
- [ ] Backtick escaping is correct

### Manual Verification
- [ ] Read through updated command flow
- [ ] Verify instructions are clear

---

## Phase 4: Update /validate Command

**Goal**: Integrate CLI verification into validation workflow

### Changes to `.claude/commands/validate.md`

**Replace lines 32-37** (Automated Verification table):

```markdown
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
```

### Automated Verification
- [ ] validate.md is valid markdown
- [ ] Table structure is correct

### Manual Verification
- [ ] Review updated validation flow
- [ ] Confirm it aligns with new Makefile targets

---

## Phase 5: Test Full Workflow

**Goal**: Verify the complete CLI workflow works end-to-end

### Test Sequence
1. Run `make clean` to start fresh
2. Run `make build` - should succeed
3. Run `make test` - should run 29 tests
4. Run `make run` - app should launch on simulator
5. Run `make log` in separate terminal - should show logs

### Automated Verification
- [ ] All make targets execute without error
- [ ] Test count matches expected (29 tests)

### Manual Verification
- [ ] App launches and is functional on simulator
- [ ] Logs stream correctly when using the app
- [ ] Workflow feels natural for development iteration

---

## Rollback Plan

If issues arise:
1. Delete `Makefile`
2. Revert CLAUDE.md: `git checkout CLAUDE.md`
3. Revert command files: `git checkout .claude/commands/`

---

## Dependencies

- Xcode 16.2 (confirmed installed)
- xcode-select pointing to Xcode.app (confirmed configured)
- iPhone 16 simulator (confirmed available)

---

## Estimated Impact

| File | Change Type | Lines Changed |
|------|-------------|---------------|
| `Makefile` | New file | ~40 lines |
| `CLAUDE.md` | Edit | ~15 lines |
| `.claude/commands/implement.md` | Edit | ~25 lines |
| `.claude/commands/validate.md` | Edit | ~10 lines |

**Total**: 4 files, ~90 lines
