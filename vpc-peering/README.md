# VPC Peering

## Overview

VPC Peering is AWS's solution for connecting multiple isolated VPCs through private networking, enabling them to communicate as if they were part of the same network. This project represents a crucial evolution from single-VPC networking to multi-VPC architectures, which are essential for building scalable, secure, and well-organized cloud infrastructures.

By default, VPCs are completely isolated from each other, they cannot communicate even if they belong to the same AWS account. VPC peering solves this by creating a private network connection that allows resources in different VPCs to communicate using private IP addresses, completely bypassing the public internet. This is fundamental for several real-world scenarios:

- **Multi-tier architectures across VPCs**: Separating application tiers (web, application, database) into different VPCs for security and organizational boundaries
- **Shared services**: Providing centralized resources (Active Directory, monitoring systems, logging infrastructure) that multiple VPCs need to access
- **Cross-account connectivity**: Enabling communication between VPCs owned by different AWS accounts (development, staging, production accounts)
- **Geographic distribution**: Connecting VPCs in different regions for disaster recovery or global applications

What makes VPC peering particularly important is that it provides private communication without internet exposure. Traffic between peered VPCs stays within AWS's network backbone, which means lower latency, better security, and significantly reduced data transfer costs compared to routing traffic through the internet.

This project builds upon all previous VPC concepts, subnets, route tables, Internet Gateways, security groups, NACLs, and EC2 instances, but introduces the critical dimension of inter-VPC networking. I learned that VPC peering is not transitive (if VPC A peers with VPC B, and VPC B peers with VPC C, that doesn't mean VPC A can communicate with VPC C), which has significant architectural implications. I also discovered the importance of CIDR planning, peered VPCs cannot have overlapping CIDR blocks, which requires careful IP address space design from the beginning.

## Architecture

![Architecture Diagram](assets/peering.png)

## Implementation Steps

### 1. Creating First VPC with 'VPC and More'

I started by creating the first VPC (VPC A) using AWS's "VPC and More" option. I configured it with a single public subnet, as this project focuses specifically on VPC peering rather than complex subnet architectures. I selected a CIDR block (for example, 10.0.0.0/16) and let AWS automatically create the associated Internet Gateway and route table. The visual resource map showed how these components connected, making it easy to verify the basic infrastructure was correct before moving forward.

### 2. Creating Second VPC with 'VPC and More'

I created the second VPC (VPC B) using the same "VPC and More" approach, but with a critically important difference: I used a non-overlapping CIDR block (for example, 10.1.0.0/16). This CIDR planning is mandatory for VPC peering. If the CIDR blocks overlap, AWS will not allow you to create a peering connection because routing becomes impossible. I again configured a single public subnet with its own Internet Gateway and route table.

### 3. Launching EC2 Instance in VPC A

I launched a public EC2 instance in VPC A's public subnet. I selected a t2.micro instance (free tier eligible) and ensured it was assigned a public IP address for internet connectivity. This instance would serve as one endpoint for my peering connectivity tests, allowing me to verify cross-VPC communication from VPC A to VPC B.

### 4. Launching EC2 Instance in VPC B

I launched a second public EC2 instance in VPC B's public subnet, also a t2.micro with a public IP address. Having instances in both VPCs was essential for testing because I needed to verify bidirectional communication across the peering connection. Both instances could reach the internet independently through their respective Internet Gateways, establishing the baseline connectivity before introducing peering.

### 5. Creating Security Groups

I created dedicated security groups for each EC2 instance in their respective VPCs. These security groups needed to allow specific inbound traffic for testing. I allowed SSH (port 22) for EC2 Instance Connect access, and crucially, I allowed ICMP (ping) traffic from the peer VPC's CIDR block. The security group configuration is what enables cross-VPC communication at the instance level once routing is established through peering.

### 6. Configuring Network Infrastructure

Before testing connectivity, I validated the network infrastructure in both VPCs. I verified that each public subnet had a route table with a 0.0.0.0/0 route pointing to the Internet Gateway (for internet access), and that the Network ACLs were using the default allow-all rules. This step ensured the baseline infrastructure was correct so that any connectivity issues would be attributable to peering configuration, not underlying network problems.

### 7. Testing Internet Connectivity

I used EC2 Connect to access each instance and tested internet connectivity by pinging a public IP address (such as 8.8.8.8). Both instances could successfully ping the internet, confirming that the basic VPC infrastructure was working correctly. At this point, the two VPCs were completely isolated from each other, attempting to ping the private IP of the instance in the other VPC would fail with a timeout because no routing path existed between the VPCs.

### 8. Creating VPC Peering Connection

I created the VPC peering connection from the VPC dashboard. I selected VPC A as the requester and VPC B as the accepter. AWS created a peering connection in a "pending acceptance" state. I then switched to the peering connections view and accepted the connection request. This two-step process (request and accept) exists because peering connections can span AWS accounts, so both sides must explicitly agree. Once accepted, the peering connection entered the "active" state, meaning the underlying network path was established.

### 9. Updating Route Tables for Peering

Creating the peering connection establishes the network path, but traffic won't flow until routing is configured. I updated the route table in VPC A to add a route for VPC B's CIDR block (10.1.0.0/16) with the peering connection as the target. Then I updated the route table in VPC B to add a route for VPC A's CIDR block (10.0.0.0/16), also targeting the peering connection. These routes tell each VPC how to reach the other VPC's address space. Both sides must be configured for bidirectional communication.

### 10. Testing Cross-VPC Connectivity

With the peering connection active and routing configured, I tested cross-VPC connectivity. From the EC2 instance in VPC A, I pinged the private IP address of the instance in VPC B. The ping succeeded, with ICMP echo replies confirming that packets were traversing the peering connection. I then reversed the test, pinging from VPC B to VPC A, which also succeeded. This bidirectional connectivity validated that peering was fully functional and that security groups, routing, and the peering connection were all correctly configured.

### 11. Cleanup

After completing the project, I cleaned up all resources to avoid ongoing charges. I first deleted the VPC peering connection (peering connections themselves are free, but it's good practice to remove unused infrastructure). Then I terminated both EC2 instances and waited for them to reach the terminated state. Finally, I deleted both VPCs, which automatically removed the associated subnets, route tables, and Internet Gateways. Proper cleanup ensures no unexpected costs and leaves the AWS environment clean for future projects.

## Security Considerations

**Private Communication Without Internet Exposure**: VPC peering provides private network connectivity between VPCs. Traffic never traverses the public internet, which means it cannot be intercepted by external attackers, provides lower latency, and avoids the security risks of internet-routed traffic. This is a fundamental security benefit, especially when connecting VPCs that contain sensitive data or backend systems.

**Peering is Not Transitive**: A critical security characteristic of VPC peering is that it is not transitive. If VPC A peers with VPC B, and VPC B peers with VPC C, VPC A cannot communicate with VPC C unless you explicitly create a peering connection between A and C. This non-transitive behavior is actually a security feature because it prevents unintended network access. You must explicitly configure each peering relationship, which enforces intentional architecture design and prevents accidental exposure of resources.

**CIDR Blocks Cannot Overlap**: VPC peering requires non-overlapping CIDR blocks, and this has security implications. It forces you to plan your IP address space carefully from the beginning. If you need to peer VPCs later and discover overlapping CIDRs, you cannot create the peering connection, which might require rebuilding entire VPCs. Proper CIDR planning prevents this scenario and is a best practice for any multi-VPC architecture.

**Route Table Configuration Controls Traffic Flow**: Security in VPC peering depends heavily on route table configuration. You can choose to route only specific subnets over the peering connection, not necessarily the entire VPC CIDR. This implements the principle of least privilege at the network layer. For example, you might peer VPC A and VPC B but only route VPC A's application subnet to VPC B's database subnet, preventing unnecessary access from other subnets.

**Principle of Least Privilege at the Network Level**: When configuring peering routes, I learned to route only the necessary CIDR blocks, not entire VPCs unless required. If VPC B has both a public and private subnet but VPC A only needs to access the private subnet, I would route only the private subnet's CIDR over the peering connection. This minimizes the attack surface and limits what resources can be reached across the peering connection.

**Cross-Account and Cross-Region Capabilities**: VPC peering supports both cross-account peering (VPCs in different AWS accounts) and cross-region peering (VPCs in different AWS regions). Cross-account peering requires both accounts to explicitly accept the connection, which provides security controls.

**Each Side Must Explicitly Accept**: The request/accept workflow for peering connections is a security control. Neither VPC can be peered without explicit consent from both sides. This prevents unauthorized peering connections and ensures that VPC owners maintain control over their network boundaries. In cross-account scenarios, this is critical because it prevents one account from unilaterally establishing connectivity to another account's resources.

## Cost Analysis

**VPC Peering Connection is Free**: AWS does not charge for the VPC peering connection itself. Creating and maintaining a peering connection between VPCs has zero infrastructure cost. This is a significant advantage over more complex networking solutions like Transit Gateway, which has hourly attachment charges.

**Data Transfer Within Same Availability Zone is Free**: When traffic flows over a VPC peering connection and both instances are in the same Availability Zone (even though they're in different VPCs), data transfer is free. AWS does not charge for data transfer between instances in the same AZ, which makes same-AZ peering extremely cost-effective for high-volume communication.

**Data Transfer Between Different Availability Zones Has Costs**: If the peered VPCs or their resources are in different Availability Zones within the same region, data transfer is charged at typical inter-AZ rates (typically $0.01 per GB in each direction). This is the same cost as inter-AZ transfer within a single VPC, so peering doesn't add cost, but it's important to understand that high-volume cross-AZ communication can add up.

**Cross-Region Peering Has Data Transfer Charges**: When peering VPCs in different AWS regions, data transfer charges apply based on the regions involved. Cross-region transfer is significantly more expensive than same-region transfer (typically $0.02 per GB or higher depending on regions). However, this is still much cheaper than routing traffic over the public internet and incurs lower latency by staying on AWS's private network backbone.

**EC2 Instances Continue to Cost Money**: The primary cost for this project was the EC2 instances running in each VPC. Even though they were t2.micro instances (free tier eligible for 750 hours per month), once free tier is exhausted or if larger instance types are used, these instances generate ongoing compute charges. The instances must be terminated after testing to avoid unnecessary costs.

**Significantly Cheaper Than Internet-Based Communication**: If I had chosen to route traffic between the two VPCs over the internet instead of peering, I would pay outbound data transfer charges ($0.09 per GB after the first 1 GB free each month). Peering avoids these expensive internet data transfer costs, making it far more economical for inter-VPC communication, especially at scale.

**Free Alternative to Transit Gateway**: For simple multi-VPC scenarios connecting a small number of VPCs, VPC peering is a free alternative to AWS Transit Gateway. Transit Gateway simplifies management when connecting many VPCs but has hourly charges ($0.05 per attachment hour). For this two-VPC scenario, peering provided the same functionality at zero cost.

## Key Takeaways

**VPC Peering Connects Isolated VPCs Privately**: The fundamental purpose of VPC peering is enabling private communication between VPCs that are otherwise completely isolated. This is essential for multi-VPC architectures and allows you to organize infrastructure by function, environment, or team while maintaining connectivity where needed.

**Peering is Not Transitive**: This was one of the most important lessons. Peering relationships must be explicitly configured between each pair of VPCs. If you have VPCs A, B, and C, and you need full mesh connectivity, you must create three peering connections (A-B, B-C, A-C). This non-transitive behavior prevents accidental network exposure but requires careful planning for complex multi-VPC architectures.

**CIDR Blocks Must Not Overlap**: Overlapping CIDR blocks make peering impossible because routing becomes ambiguous. This requirement forces proper IP address planning from the beginning. I learned to use distinct private IP ranges for each VPC (10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16, etc.) to ensure future peering flexibility.

**Route Tables Must Be Updated on Both Sides**: Creating the peering connection is only half the work. Routing must be configured in both VPCs for bidirectional communication. Each VPC's route table needs a route to the peer VPC's CIDR block with the peering connection as the target. Forgetting to update routes on both sides is a common mistake that prevents connectivity.

**Security Groups Control Cross-VPC Traffic**: Even with peering and routing configured, security groups determine what traffic actually flows between VPCs. I learned to configure security group rules that explicitly allow traffic from the peer VPC's CIDR block or security groups. Without these rules, connectivity tests like ping would fail even though the network path exists.

**Private Communication Without Internet Exposure**: VPC peering keeps all traffic on AWS's private network. This provides security benefits (no internet exposure), performance benefits (lower latency), and cost benefits (avoiding expensive internet data transfer charges). This makes peering ideal for backend-to-backend communication between VPCs.

**Useful for Multi-Tier Applications Across VPCs**: I can now envision architectures where the web tier is in one VPC, the application tier in another, and the database tier in a third, all connected via peering. This separation provides security and organizational boundaries while maintaining the communication necessary for the application to function.

**Foundation for Understanding More Complex Networking**: VPC peering introduced me to multi-VPC networking concepts that are foundational for understanding more advanced AWS networking services like Transit Gateway, AWS PrivateLink, and complex hybrid cloud architectures. Peering is the simplest multi-VPC solution, which makes it the best place to start learning.

**Testing Validates Both Baseline and Cross-VPC Connectivity**: The testing methodology I used, first validating internet connectivity from each VPC independently, then testing cross-VPC connectivity after peering, was essential. This systematic approach ensured I understood what worked at each stage and could troubleshoot issues by isolating whether they were baseline connectivity problems or peering-specific problems.

**Hands-On Testing Makes Routing Concepts Concrete**: Reading about route tables and peering connections is one thing, but actually configuring routes, testing connectivity, watching ping packets traverse the peering connection, and troubleshooting when it doesn't work made routing concepts tangible. This hands-on experience transformed abstract networking theory into practical cloud engineering skills.
