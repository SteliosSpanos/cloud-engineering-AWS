# Build your own Virtual Private Cloud

## Overview

A Virtual Private Cloud (VPC) is a logically isolated section of AWS where you can launch resources in a network you define. Think of it as your own private data center in the cloud, where you have complete control over IP addressing, subnets, route tables, and network gateways.

The key components I worked with include:
- **VPC**: The container for your entire network, defined by a CIDR block
- **Subnets**: Subdivisions of your VPC that can be public (internet-accessible) or private (isolated)
- **Internet Gateway**: The bridge that allows communication between your VPC and the internet

Understanding VPCs is fundamental because they form the network foundation for everything else in AWS.

## Architecture

![Architecture Diagram](assets/vpc-screenshot.png)

## Implementation Steps

### 1. Learning Phase
I started by understanding what VPCs are and why they're essential for cloud networking. The concept of creating your own isolated network segment within AWS's infrastructure was eye-opening.

### 2. Understanding Public vs Private Subnets
I learned the critical distinction between subnet types:
- **Public subnets**: Have a route to an Internet Gateway, allowing resources to communicate with the internet
- **Private subnets**: No direct internet access, used for backend resources like databases and application servers

### 3. Creating the VPC
I created a VPC with a custom CIDR block (e.g., 10.0.0.0/16), which defines the range of IP addresses available within my network. This gave me up to 65,536 IP addresses to work with.

### 4. Understanding Availability Zones
I explored how AWS organizes infrastructure into Availability Zones (AZs), which are physically separate data centers within a region. Distributing resources across AZs is crucial for high availability.

### 5. Creating a Public Subnet
I created a subnet within my VPC, selecting an Availability Zone and defining a smaller CIDR block (e.g., 10.0.1.0/24) that's a subset of the VPC's range.

### 6. Enabling Auto-Assign Public IPv4
I enabled the auto-assign public IPv4 address setting on my subnet. This ensures that any EC2 instances launched in this subnet automatically receive a public IP address, making them internet-accessible.

### 7. Creating and Attaching an Internet Gateway
I created an Internet Gateway and attached it to my VPC. The Internet Gateway acts as the doorway between my VPC and the internet.

### 8. Cleanup
To avoid any unexpected charges, I deleted all resources in reverse order: detached and deleted the Internet Gateway, deleted the subnet, and finally deleted the VPC.

## Security Considerations

**VPC Isolation**: The VPC provides complete network isolation. My resources are logically separated from other AWS customers and even from my own other VPCs.

**Public vs Private Security**: Public subnets expose resources to the internet, which is necessary for web servers but increases attack surface. Private subnets keep databases and application servers isolated, accessible only from within the VPC.

**Internet Gateway Control**: The Internet Gateway serves as a controlled entry and exit point. Without it, even resources with public IPs cannot communicate with the internet.

**Network Segmentation**: VPCs enable the security best practice of network segmentation. You can separate different tiers of your application (web, application, database) into different subnets with different security policies.

**Production Best Practice**: In production, private subnets are essential for databases, application servers, and any backend component that shouldn't be directly accessible from the internet.

## Cost Analysis

**VPC**: Free - AWS doesn't charge for creating or maintaining VPCs.

**Subnets**: Free - No cost for subnet creation or existence.

**Internet Gateway**: Free - No charge for the Internet Gateway itself, only for data transfer.

**Data Transfer**: Costs apply for data transferred out to the internet. This is where actual costs would occur.

**EC2 Instances**: While the VPC infrastructure itself is free, any instances launched within it would incur standard EC2 charges.

**Importance of Cleanup**: Even though VPC components are mostly free, practicing proper cleanup is essential. It maintains a clean environment, and builds good cloud habits that become critical when working with resources that do cost money.

## Key Takeaways

- **VPCs are fundamental**: They're the networking foundation for all AWS services and enable secure, isolated cloud architectures.

- **CIDR blocks matter**: Understanding IP addressing and CIDR notation is essential for network design.

- **Public vs private is a security decision**: The subnet type determines internet accessibility. This architectural decision impacts security, cost, and functionality.

- **Internet Gateways enable connectivity**: Without an Internet Gateway and proper routing, resources remain isolated even if they have public IPs.

- **Availability Zones enable resilience**: Distributing resources across AZs is how you build highly available systems on AWS.


