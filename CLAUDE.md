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
├── static-website-s3/         # Project 1: S3 static website hosting
│   ├── README.md
│   └── assets/                # Architecture diagrams
├── IAM-cloud-security/        # Project 2: IAM with tag-based access control
│   ├── README.md
│   └── assets/                # Architecture diagrams
├── virtual-private-cloud/     # Project 3: VPC networking fundamentals
│   ├── README.md
│   └── assets/                # Architecture diagrams
├── vpc-traffic-flow-security/ # Project 4: VPC traffic flow and security
│   ├── README.md
│   └── assets/                # Architecture diagrams
├── vpc-private-subnet/        # Project 5: Private subnets and network isolation
│   ├── README.md
│   └── assets/
├── vpc-launching-resources/   # Project 6: Launching EC2 instances in VPC
│   ├── README.md
│   └── assets/
├── vpc-testing-connectivity/  # Project 7: Testing VPC connectivity and validation
│   ├── README.md
│   └── assets/
├── vpc-peering/               # Project 8: VPC peering and inter-VPC connectivity
│   ├── README.md
│   └── assets/
├── vpc-monitoring/            # Project 9: VPC monitoring and Flow Logs
│   ├── README.md
│   └── assets/
└── [future-projects]/         # Each project gets its own folder
    └── README.md
```

## Current Projects

1. **Static Website Hosting on S3** - S3 bucket configuration, ACLs, static website hosting
2. **Cloud Security with IAM** - IAM policies (JSON), user groups, tag-based access control, EC2 instances
3. **Build your own Virtual Private Cloud** - VPC creation, subnets (public/private), Internet Gateway, Availability Zones
4. **VPC Traffic Flow and Security** - Security groups, NACLs, route tables, traffic control in VPC
5. **VPC Private Subnets** - Private subnet creation, route table isolation, Network ACLs, multi-tier architecture
6. **Launching VPC Resources** - EC2 instance deployment, public/private instances, security group configuration, VPC and More feature
7. **Testing VPC Connectivity** - EC2 Instance Connect, SSH, ping/ICMP, curl, connectivity testing, network validation
8. **VPC Peering** - VPC peering connections, cross-VPC routing, private inter-VPC communication, multi-VPC architecture
9. **VPC Monitoring with Flow Logs** - VPC Flow Logs, CloudWatch, log groups, IAM roles with trust policies, Logs Insights, network traffic analysis

## Documentation Standards

**Agent Usage:** ALWAYS use the `technical-documentation-architect` agent when creating or updating documentation. Use the Task tool with `subagent_type="technical-documentation-architect"` for all README creation and updates.

**Format:** All project documentation uses Markdown (.md)
- GitHub-native rendering
- Industry standard for portfolio projects
- Simple, maintainable syntax

**Required README Sections:**
1. **Overview** - Brief description, problem solved, technologies used, what the AWS service does
2. **Architecture** - Diagram (stored in assets/ folder) and service interaction explanation
3. **Implementation Steps** - High-level process, key decisions, what was learned during implementation
4. **Security Considerations** - Policies, permissions, encryption, best practices, lessons learned
5. **Cost Analysis** - Services used, estimated costs, free tier info, teardown procedures
6. **Key Takeaways** - Learnings and future improvements
7. **Resources** - Helpful documentation/tutorial links

**Important Principles:**
- Write in first person ("I created...", "I learned...") - this is a learning journey
- Focus on thought process and decision-making, not step-by-step tutorials
- Security is emphasized in every project (cloud + security career path)
- Include architecture diagrams in assets/ folder
- Document costs and cleanup (demonstrates real-world awareness)
- Keep concise (300-600 words for Implementation, Security, and Key Takeaways sections)
- Explain the WHY behind decisions, not just the WHAT

## Git Workflow

- Main branch: `main`
- No specific branching strategy (single contributor)
- Commit messages describe documentation additions (e.g., "Adds architecture diagram", "Completes IAM project documentation")
- No code deployment/CI-CD - this is a documentation-only repository

## Security Notes

- Never commit AWS credentials, access keys, or sensitive information
- Document security decisions made in each project
- Include IAM policies, bucket policies, and access control explanations
- All projects are torn down after completion to avoid costs and security risks

## Working with This Repository

**When adding a new project:**
1. Create new folder with descriptive name (e.g., `lambda-serverless-api/`)
2. Use the technical-documentation-architect agent to create the README
3. Add assets/ subfolder for architecture diagrams
4. Update root README.md to list the new project in the Projects section
5. Follow the documentation standards above

**When updating project documentation:**
1. Always use the technical-documentation-architect agent
2. Provide the agent with: project folder, what was implemented, steps followed, services used
3. Review agent output before finalizing
4. Ensure all required sections are complete

**Documentation workflow:**
- User provides project details and implementation steps
- Use Task tool with technical-documentation-architect agent
- Agent creates comprehensive, well-structured documentation
- Review and commit changes
