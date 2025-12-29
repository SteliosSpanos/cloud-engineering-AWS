# VPC Monitoring with Flow Logs

## Overview

VPC Flow Logs are a critical observability feature that captures metadata about network traffic flowing through your VPC. Unlike packet capture tools that record entire packets, Flow Logs collect information about the 5-tuple: source IP, destination IP, source port, destination port, and protocol. This provides visibility into who is talking to what, when, and whether the traffic was accepted or rejected by security groups or NACLs.

I built this project to add network monitoring capabilities to the VPC infrastructure I developed in previous projects. Flow Logs solve several key challenges: security monitoring and threat detection, network troubleshooting and performance analysis. By integrating Flow Logs with CloudWatch, I gained a centralized logging platform with powerful querying capabilities through CloudWatch Logs Insights.

This project represents the culmination of my VPC learning journey. While previous projects focused on building infrastructure (subnets, routing, peering, security), this project adds the observability layer that makes production VPCs manageable. Without Flow Logs, your network is essentially a black box. With them, you can detect port scans, identify misconfigured security groups, troubleshoot connectivity issues, and maintain compliance with audit requirements.

The technologies involved include VPC Flow Logs for traffic capture, CloudWatch Logs for storage and retention, CloudWatch Logs Insights for SQL-like querying, and IAM roles with trust policies to grant the Flow Logs service permission to write logs. This project taught me that monitoring is not optional in cloud infrastructure, it's fundamental to operating securely and reliably.

## Architecture

![Architecture Diagram](assets/pic.png)

## Implementation Steps

### 1. VPC Infrastructure Foundation

I continued from the VPC Peering project, which already had two VPCs with public and private subnets, EC2 instances, security groups, and a peering connection. This existing infrastructure provided the network traffic I needed to monitor. The key insight here is that Flow Logs don't require changes to your VPC architecture, they're purely observational and don't impact network performance or routing.

### 2. Setting Up CloudWatch

I learned that CloudWatch is AWS's unified monitoring and logging platform. It collects metrics, logs, and events from AWS services and provides tools for visualization, alerting, and analysis. For Flow Logs, CloudWatch serves as the log repository. I needed to create a log group, which is a container that organizes related log streams. Each network interface (ENI) in my VPC would generate its own log stream within the group.

### 3. Understanding Log Groups and Log Classes

CloudWatch offers two log classes: Standard and Infrequent Access. Standard class supports all CloudWatch Logs features and is suitable for frequently accessed logs. Infrequent Access class costs less for storage but has higher query costs and is designed for logs you rarely query but need to retain for compliance. I chose Standard class because I planned to actively query my Flow Logs while learning. This taught me that AWS provides cost optimization options even within logging services.

### 4. Learning About Flow Logs and ENIs

I discovered that Flow Logs capture traffic at the Elastic Network Interface (ENI) level. Every EC2 instance has at least one ENI, which is the virtual network card that connects it to the VPC. Flow Logs record metadata about traffic to and from these ENIs, including accepted and rejected connections. Importantly, Flow Logs don't capture packet payloads, only metadata. This means you can't see the content of HTTP requests or SSH sessions, but you can see that the connections occurred.

### 5. Creating IAM Policy for Flow Logs

I created an IAM policy that grants permissions to create log groups, create log streams, and put log events into CloudWatch. The policy specifies actions like `logs:CreateLogGroup`, `logs:CreateLogStream`, and `logs:PutLogEvents`. This policy defines what the Flow Logs service can do, but it doesn't define who can use it. That's where the IAM role comes in. This step reinforced the principle of least privilege, granting only the specific permissions needed for the task.

### 6. Creating IAM Role with Trust Policy

I created an IAM role and attached the policy from the previous step. The critical piece was the trust policy, which defines which AWS services can assume the role. I configured the trust policy to allow `vpc-flow-logs.amazonaws.com` to assume the role. This is an example of service-to-service authentication. The Flow Logs service assumes the role and inherits the permissions to write logs to CloudWatch. Trust policies answer the question "who can use this role?" while permission policies answer "what can this role do?"

### 7. Configuring VPC Flow Logs

I enabled Flow Logs on my VPC, specifying the IAM role I created, the CloudWatch log group as the destination, and the traffic filter (all traffic, accepted only, or rejected only). I chose to capture all traffic to get complete visibility. I also configured the log format, selecting the default format which includes source IP, destination IP, source port, destination port, protocol, packets, bytes, start time, end time, and action (ACCEPT or REJECT). Flow Logs began capturing traffic immediately, though there's a few minutes of delay before logs appear in CloudWatch.

### 8. Testing Connectivity to Generate Traffic

To populate my logs with data, I generated various types of network traffic. I pinged between instances in peered VPCs to create ICMP traffic. I SSH'd into public instances to create TCP port 22 traffic. I used curl to make HTTP requests, generating TCP port 80/443 traffic. I also intentionally triggered some rejected connections by attempting to connect on ports blocked by security groups. This created a diverse dataset for analysis and helped me understand what accepted versus rejected traffic looks like in the logs.

### 9. Viewing Log Streams in CloudWatch

I navigated to CloudWatch, selected my log group, and viewed the log streams. Each ENI had its own stream with raw log entries. The log format is space-delimited, showing fields like `2 123456789012 eni-abc123 10.0.1.50 10.0.2.100 12345 22 6 25 5000 1640000000 1640000060 ACCEPT OK`. This taught me to read the logs: version, account ID, interface ID, source IP, destination IP, source port, destination port, protocol (6=TCP), packets, bytes, start time, end time, action, and log status. Reading raw logs is tedious, which is why Logs Insights exists.

### 10. Using CloudWatch Logs Insights

I discovered CloudWatch Logs Insights, a powerful query engine with a SQL-like syntax. I wrote queries to filter and analyze my Flow Logs. For example, I queried for all rejected traffic with `fields @timestamp, srcAddr, dstAddr, dstPort, action | filter action = "REJECT" | sort @timestamp desc`. This immediately showed me which connections were being blocked by security groups or NACLs. I also queried for traffic to specific ports, top talkers by IP address, and traffic volume over time. Logs Insights transformed raw log data into actionable insights. This tool is invaluable for troubleshooting and security analysis.

### 11. Cleanup

After completing the project, I deleted the Flow Logs configuration to stop accumulating charges. I also deleted the CloudWatch log group (which deletes all log streams and stored data), and removed the IAM role and policy I created. This cleanup process is essential for cost management and demonstrates good cloud hygiene. Leaving Flow Logs enabled on high-traffic VPCs can generate significant costs from log ingestion and storage.

## Security Considerations

VPC Flow Logs are fundamentally a security tool. They provide visibility into network traffic patterns, which is essential for detecting threats, investigating incidents, and maintaining compliance. Flow Logs fulfill this requirement by creating an immutable record of who connected to what and when.

One of the most valuable security use cases is detecting suspicious traffic patterns. By querying Flow Logs for rejected connections, I can identify port scanning attempts, brute force attacks, and other reconnaissance activities. Attackers often probe for open ports before exploiting vulnerabilities. Rejected traffic logs reveal these attempts even when security groups successfully block them. This taught me that blocked traffic is just as important as allowed traffic for security monitoring.

Flow Logs capture metadata only, not packet contents. This is a security feature, not a limitation. It means logs don't contain sensitive application data, credentials, or personal information that might be transmitted over the network. You get visibility without the privacy and compliance concerns of full packet capture. However, IP addresses and ports are logged, which can still be considered sensitive in some contexts. I ensured my CloudWatch logs have appropriate IAM access controls so only authorized users can query them.

The IAM role and trust policy configuration taught me about service-to-service security. The trust policy explicitly restricts role assumption to the VPC Flow Logs service, preventing other services or users from assuming the role. Even if an attacker compromised my AWS account, they couldn't use the Flow Logs role for unauthorized purposes because the trust policy blocks assumption from anything except the Flow Logs service.

Log retention is a critical security consideration. CloudWatch allows configuring retention periods from 1 day to indefinitely. For security investigations, you often need historical data to trace attack timelines. I set a 30-day retention to balance security needs with cost. This taught me that logging strategy requires balancing storage costs against investigative requirements. 

Finally, I learned that monitoring rejected traffic can reveal misconfigurations just as often as attacks. If legitimate traffic is being rejected, Flow Logs help you identify the offending security group or NACL rule. This dual use—security monitoring and troubleshooting—makes Flow Logs essential for operational excellence.

## Cost Analysis

VPC Flow Logs introduce several cost components. The primary cost is data ingestion, charged per GB of log data published to CloudWatch. AWS charges approximately $0.50 per GB for Flow Logs data in the US East region. The volume of log data depends on your network traffic volume and the number of ENIs being monitored. A busy production VPC can generate hundreds of gigabytes of logs per month, making this a significant cost factor.

CloudWatch Logs storage costs depend on the log class and retention period. Standard class costs around $0.50 per GB per month, while Infrequent Access class costs $0.03 per GB per month but has higher query costs. I chose Standard class for active learning, but production environments should analyze query patterns to optimize between Standard and Infrequent Access. Short retention periods (7-30 days) reduce storage costs, while compliance requirements may mandate longer retention.

CloudWatch Logs Insights charges per query based on the amount of data scanned. Queries cost approximately $0.005 per GB scanned. This seems small, but scanning terabytes of logs repeatedly can add up. I learned to write efficient queries that filter early in the query pipeline to minimize scanned data. For example, filtering by time range first reduces the dataset before applying more complex filters.

The traffic filter setting affects costs significantly. Capturing all traffic (accepted and rejected) doubles log volume compared to capturing only accepted traffic. I captured all traffic for learning, but production environments should consider whether rejected traffic logs justify the additional cost. For security monitoring, the answer is often yes, rejected traffic reveals attack attempts. For pure performance monitoring, accepted traffic may suffice.

The AWS Free Tier includes 5 GB of log data ingestion and 5 GB of log storage per month for CloudWatch Logs. My learning project stayed within free tier limits because my test VPC had minimal traffic. However, production VPCs with real workloads quickly exceed free tier, so cost planning is essential.

I also learned about the cost-benefit tradeoff of monitoring. Operating infrastructure without visibility is risky since you can't troubleshoot issues, detect security threats, or optimize performance. The cost of Flow Logs is an investment in operational excellence and security. A single security incident or prolonged outage due to undiagnosed network issues can cost far more than Flow Logs. This taught me that monitoring is a fundamental operational requirement.

Cleanup is critical for cost control. I deleted Flow Logs, log groups, and retained data after completing the project. Forgetting to disable Flow Logs on test infrastructure is a common source of unexpected AWS bills. Always implement teardown procedures and use cost monitoring alerts to catch runaway charges.

## Key Takeaways

This project taught me that observability is just as important as the infrastructure itself. Building VPCs, subnets, and security groups creates the foundation, but Flow Logs provide the visibility to operate that infrastructure reliably and securely. Without monitoring, you're flying blind, troubleshooting becomes guesswork, and security threats go undetected.

VPC Flow Logs capture network traffic metadata without impacting performance. This is achieved by sampling traffic at the hypervisor level, outside the data path. There's no latency penalty or throughput reduction from enabling Flow Logs. This taught me that AWS has engineered observability features to be production-safe from day one.

CloudWatch is AWS's centralized monitoring and logging platform, integrating with virtually every AWS service. Flow Logs are just one data source; CloudWatch also collects metrics, application logs, events, and traces. Learning CloudWatch for Flow Logs gave me skills applicable to monitoring Lambda functions, RDS databases, and other AWS services. This platform approach simplifies operations by providing a single pane of glass for observability.

Log groups and log streams provide hierarchical organization for logs. A log group contains related log streams from multiple sources. For Flow Logs, each ENI gets its own stream within the group. This organization makes it easy to find logs for specific resources while maintaining logical grouping. I learned that good log organization is essential for operational efficiency as infrastructure scales.

IAM roles with trust policies enable service-to-service permissions. The trust policy controls which AWS services can assume the role, while the permission policy controls what the role can do. This separation of concerns is a powerful security pattern. I can grant the Flow Logs service permission to write logs without granting those permissions to users or other services. This reinforced my understanding of the principle of least privilege and defense in depth.

Flow Logs record the 5-tuple: source IP, destination IP, source port, destination port, and protocol. This metadata is sufficient for most troubleshooting and security analysis without the complexity and privacy concerns of full packet capture. I learned to think about network traffic in terms of connections and flows rather than individual packets. This abstraction is powerful for understanding network behavior at scale.

CloudWatch Logs Insights provides SQL-like querying for log analysis. I can filter, aggregate, sort, and visualize log data without exporting to external tools. The query language supports complex operations like parsing JSON, regular expressions, and statistical functions. This taught me that AWS provides sophisticated analysis tools integrated with its logging platform.

Rejected traffic logs are invaluable for security monitoring. They reveal blocked connection attempts that could indicate port scans, brute force attacks, or misconfigured applications. I learned to treat rejected traffic as a security signal, not just noise. Analyzing rejected traffic patterns helps identify threats early and validate that security controls are working as intended.

Network monitoring is essential for production environments. The cost of Flow Logs is a small investment compared to the operational and security benefits. Troubleshooting without logs is time-consuming and error-prone. Security monitoring without visibility is impossible. Compliance requirements often mandate traffic logging. For all these reasons, Flow Logs should be enabled on production VPCs from day one.
