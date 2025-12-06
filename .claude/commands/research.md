# Research Codebase

You are conducting research on the codebase. DO NOT write any code during this phase.

## Instructions

1. **Spawn parallel sub-agents** to investigate different aspects of the codebase simultaneously using the Task tool with `subagent_type=Explore`

2. **Research areas to explore** (customize based on the request):
   - Relevant file locations and architecture
   - Existing patterns and conventions
   - Dependencies and integrations
   - Potential impact areas
   - Edge cases and constraints

3. **Output requirements**:
   - Save your research findings to `thoughts/shared/research/[topic]-[date].md`
   - Include specific file paths with line numbers
   - Document architectural insights
   - List any questions or ambiguities discovered

4. **Format for research document**:
```markdown
# Research: [Topic]
Date: [YYYY-MM-DD]

## Summary
[Brief overview of findings]

## Key Files
- `path/to/file.swift:123` - [description]

## Architecture Insights
[How this fits into the existing system]

## Constraints & Considerations
[Limitations, edge cases, dependencies]

## Open Questions
[Anything that needs clarification]
```

## Important
- This is RESEARCH ONLY - no code changes
- Be thorough - spawn multiple sub-agents for parallel investigation
- Reference specific files and line numbers
- After research is complete, use `/clear` before proceeding to planning

User request: $ARGUMENTS
