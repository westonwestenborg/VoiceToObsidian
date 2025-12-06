# thoughts/

Persistent knowledge repository for Claude Code sessions. This directory stores research, plans, and documentation that persists across context resets.

## Directory Structure

```
thoughts/
├── personal/           # Individual session notes and scratchpads
├── shared/             # Team-shared knowledge
│   ├── research/       # Codebase research documents
│   └── plans/          # Implementation plans and validations
└── searchable/         # Symlinked content for AI search
```

## Usage

### Research (`shared/research/`)
Output from `/research` command. Contains:
- Codebase analysis
- Architecture documentation
- File references with line numbers

### Plans (`shared/plans/`)
Output from `/plan` command. Contains:
- Implementation plans
- Validation reports
- Success criteria tracking

### Personal (`personal/`)
Session-specific notes:
- Scratchpads during implementation
- Debugging notes
- Temporary context

## Workflow

1. **Research**: `/research [topic]` → saves to `shared/research/`
2. **Plan**: `/plan [feature]` → saves to `shared/plans/`
3. **Implement**: `/implement [plan]` → executes phases
4. **Validate**: `/validate [feature]` → saves report to `shared/plans/`

## Best Practices

- Reference these files in prompts instead of re-explaining context
- Use `/clear` between phases to manage context
- Keep research and plans updated as you discover new information
