# VPC Traffic Flow and Security

## Overview

Building upon the foundational VPC networking concepts from the previous project, this project dives into the security and traffic control mechanisms that make AWS VPCs production-ready. While creating a VPC, subnets, and an Internet Gateway establishes the network infrastructure, understanding how to control traffic flow and implement security layers is what transforms that infrastructure into a secure, functional environment.

This project focuses on three critical components:
- **Route Tables**: Control where network traffic is directed, both within the VPC and to the internet
- **Security Groups**: Stateful firewalls that operate at the resource level (like EC2 instances)
- **Network ACLs**: Stateless firewalls that operate at the subnet level

The key distinction I learned is that Security Groups are **stateful** (they automatically allow return traffic for allowed inbound connections), while Network ACLs are **stateless** (you must explicitly allow both inbound and outbound traffic).

## Architecture

![Architecture Diagram](assets/traffic-flow.png)

## Implementation Steps

### 1. VPC Foundation Setup

I started by creating the foundational VPC infrastructure, continuing from the previous VPC project. This included creating a VPC with a custom CIDR block, defining public subnets across Availability Zones, and creating an Internet Gateway. These components formed the base network layer upon which I would build the traffic control and security mechanisms.

### 2. Creating and Configuring Route Tables

Next, I created a route table and associated it with my VPC. A route table contains a set of rules (called routes) that determine where network traffic is directed. Every VPC comes with a default route table, but creating custom route tables gives you control over traffic routing for different subnets.

### 3. Understanding Route Table Rules

I learned about two critical routing concepts:
- **0.0.0.0/0 (default route)**: This CIDR block represents all internet traffic. When you create a route with destination 0.0.0.0/0 pointing to an Internet Gateway, you're saying "send all internet-bound traffic through this gateway."
- **Local routes**: Every route table automatically includes a local route for the VPC's CIDR block (e.g., 10.0.0.0/16). This enables all subnets within the VPC to communicate with each other without needing explicit routes.

Understanding these concepts was crucial because route tables are how you define whether a subnet is truly "public" or "private."

### 4. Connecting Route Table to Internet Gateway

I connected my route table to the Internet Gateway by adding a route with destination 0.0.0.0/0 and target set to my Internet Gateway ID. This configuration enables internet connectivity for any subnet associated with this route table. Without this route, even resources with public IP addresses cannot communicate with the internet—they have no path to get there.

### 5. Implementing Security Groups

I created a security group, which acts as a virtual firewall for resources like EC2 instances. The key insight here is that security groups **associate with resources**, not subnets. When you launch an EC2 instance, you specify which security group(s) it belongs to.

### 6. Configuring Security Group Rules

I configured my security group to allow all inbound HTTP traffic (port 80) from any source (0.0.0.0/0). In a learning environment, this permissive rule helps you understand traffic flow without getting blocked by overly restrictive rules. However, I noted that in production, you would apply the principle of least privilege, only allowing traffic from specific sources on specific ports that your application actually needs.

### 7. Implementing Network ACLs

I implemented a Network ACL, which is another layer of security. Unlike security groups that associate with resources, ACLs **associate with subnets**. This means every resource in that subnet is subject to the ACL's rules. ACLs operate at a lower level in the network stack and evaluate traffic before it reaches security groups.

### 8. Configuring Network ACL Rules

I configured my Network ACL to allow all inbound and outbound traffic. This broad configuration was intentional for learning purposes. The critical lesson was understanding that ACLs are stateless, meaning I had to explicitly allow both directions of traffic. Unlike security groups, which automatically allow response traffic, ACLs require explicit allow rules for both incoming and outgoing packets.

### 9. Cleanup

To maintain a clean AWS environment and avoid any potential costs, I deleted all resources in the proper order: removed security group associations, deleted security groups, deleted route table associations, deleted route tables and NACLs, detached and deleted the Internet Gateway, deleted subnets, and finally deleted the VPC. This reverse-order deletion is important because AWS enforces dependencies between resources.

## Security Considerations

**Defense in Depth**: One of the most important security principles I learned is defense in depth. Having both Security Groups and Network ACLs provides layered security. Even if one layer is misconfigured, the other can still protect your resources.

**Stateful vs Stateless**: Understanding the difference between stateful (Security Groups) and stateless (NACLs) firewalls is critical. Security Groups automatically track connections and allow return traffic, which simplifies rule creation. ACLs require explicit rules for both directions, which gives more control but requires more careful configuration. For example, allowing inbound HTTP on port 80 also requires allowing outbound ephemeral ports (1024-65535) for the response traffic.

**Operating Levels**: Security Groups operate at the instance level, meaning you can have different security groups for different instances within the same subnet. ACLs operate at the subnet level, applying to all resources in that subnet. This hierarchy allows you to implement broad subnet-level policies (via ACLs) while fine-tuning access at the instance level (via Security Groups).

**Best Practice - Use Both**: AWS best practices recommend using both Security Groups and ACLs. Security Groups should be your primary control mechanism because they're stateful and easier to manage. ACLs should serve as an additional layer of protection, especially useful for blocking specific IP addresses or implementing subnet-wide rules.

**Learning vs Production Configuration**: In this lab, I used permissive rules (allow all traffic) to focus on understanding the mechanisms. In production, you must follow the principle of least privilege. Only allow the specific traffic your application needs. For a web server, this might mean allowing only inbound traffic on ports 80 (HTTP) and 443 (HTTPS) from the internet, and SSH (port 22) from your office IP address only.

**Route Table Security**: Route tables control traffic flow direction, which has security implications. A misconfigured route table could send sensitive traffic through unintended paths or expose private subnets to the internet. Always validate that your route tables match your intended network architecture.

**Deny by Default**: Both Security Groups and ACLs follow a "deny by default" model. Unless you explicitly allow traffic, it's blocked. This is much safer than "allow by default" models where you would need to explicitly block malicious traffic.

## Cost Analysis

**Route Tables**: Free - AWS does not charge for creating, managing, or using route tables. You can create as many route tables as you need without incurring costs.

**Security Groups**: Free - There is no cost for security groups regardless of how many you create or how many rules they contain.

**Network ACLs**: Free - NACLs, like security groups and route tables, are free to create and use. AWS doesn't charge for these security mechanisms.

**VPC Infrastructure**: Free - As established in the previous project, VPCs, subnets, and Internet Gateways themselves are free. AWS doesn't charge for the networking infrastructure.

**Data Transfer Costs**: While the security and routing components are free, you pay for data transferred out to the internet through the Internet Gateway. However, these are usage-based costs, not charges for the infrastructure itself.

**EC2 and Other Resources**: The only costs would come from resources you launch within this infrastructure, such as EC2 instances. The security and routing mechanisms protecting those resources add zero additional cost.

## Key Takeaways

**Stateful vs Stateless is Fundamental**: Understanding that Security Groups are stateful (automatically allowing return traffic) while ACLs are stateless (requiring explicit rules for both directions) is crucial for troubleshooting connectivity issues and designing secure architectures. This distinction affects how you design your rules and how you troubleshoot when traffic isn't flowing as expected.

**Route Tables Control Destinations**: Route tables are about "where does this traffic go?" They determine whether traffic destined for the internet reaches the Internet Gateway, or whether traffic stays within the VPC. The 0.0.0.0/0 destination pointing to an IGW is what makes a subnet truly "public."

**The Meaning of 0.0.0.0/0**: This CIDR notation represents "all possible IPv4 addresses". Understanding CIDR notation is essential for cloud networking. A /0 subnet mask means no bits are fixed, so it matches everything.

**Local Routes Handle Internal Traffic**: Every route table automatically includes local routes that enable communication between all subnets within your VPC. This automatic routing is why instances in different subnets (but same VPC) can communicate without explicit routes.

**Association Matters**: Security Groups associate with resources (EC2 instances, load balancers, etc.), while ACLs associate with subnets. Choosing the right tool for the right level of control is an important architectural decision.

**Defense in Depth Works**: Using both Security Groups and ACLs provides redundant security layers. If you misconfigure one, the other can still protect you.

**Testing Traffic Flow is Essential**: The only way to truly understand if your route tables, security groups, and ACLs are configured correctly is to test them. In this project, I tested by attempting to access resources and verifying traffic flow.

**Security is Free**: AWS provides powerful security tools at no additional cost. There's no financial barrier to implementing proper security, only the effort to understand and configure these tools correctly.
