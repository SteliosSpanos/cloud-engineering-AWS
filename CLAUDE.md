# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a learning portfolio repository documenting AWS cloud projects by a CS student focused on cloud computing and security.

**Root README.md** provides an overview of all projects and the learning journey.

Each project folder contains its own detailed README.md with:
- Project overview and architecture
- Implementation details and thought process
- Security considerations
- Cost analysis
- Key takeaways

The goal is to demonstrate hands-on AWS experience and cloud security knowledge for career development.

## Repository Structure

```
Cloud/
├── static-website-s3/     # First project: S3 static website hosting
│   └── README.md
└── [future-projects]/     # Each project gets its own folder
    └── README.md
```

## Documentation Standards

**Format:** All project documentation uses Markdown (.md)
- GitHub-native rendering
- Industry standard for portfolio projects
- Simple, maintainable syntax

**Required README Sections:**
1. **Overview** - Brief description, problem solved, technologies used
2. **Architecture** - Diagram and service interaction explanation
3. **Implementation Steps** - High-level process and key decisions
4. **Security Considerations** - Policies, permissions, encryption, lessons learned
5. **Cost Analysis** - Services used, estimated costs, teardown procedures
6. **Key Takeaways** - Learnings and future improvements
7. **Resources** - Helpful documentation links

**Important Principles:**
- Focus on thought process and decision-making, not step-by-step tutorials
- Security is emphasized in every project (cloud + security career path)
- Include architecture diagrams (even simple ones show effort)
- Document costs and cleanup (demonstrates real-world awareness)
- Keep concise (300-500 words per project)

## Git Workflow

- Main branch: `main`
- Commit messages should describe the documentation additions (e.g., "Adds architecture diagram", "Includes security considerations")
- No code deployment/CI-CD - this is a documentation-only repository

## Security Notes

- Never commit AWS credentials, access keys, or sensitive information
- Document security decisions made in each project
- Include IAM policies, bucket policies, and access control explanations
