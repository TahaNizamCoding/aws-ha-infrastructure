# Highly Available AWS Infrastructure (Terraform)

A self-healing web tier built on AWS: a Multi-AZ VPC, an Application Load
Balancer, and an Auto Scaling Group that reacts to real traffic instead of a
fixed instance count. Built to survive an AZ outage, absorb a traffic spike,
and recover without anyone paging in at 2am.

## Architecture

```
                         Internet
                            |
                    [ Internet Gateway ]
                            |
                    ┌───────────────┐
                    │  ALB (public)  │  <- spans both AZs, health-checks targets
                    └───────┬───────┘
                ┌───────────┴───────────┐
        ┌───────▼───────┐       ┌───────▼───────┐
        │  AZ-a          │       │  AZ-b          │
        │  Public subnet │       │  Public subnet │
        │  ┌──────────┐  │       │  ┌──────────┐  │
        │  │ EC2 (ASG) │  │      │  │ EC2 (ASG) │  │
        │  └──────────┘  │       │  └──────────┘  │
        │  Private subnet│       │  Private subnet│
        │  (reserved)    │       │  (reserved)    │
        └────────────────┘       └────────────────┘
```

- **VPC across 2 AZs** — a single AZ is a single point of failure by
  definition, so the whole stack is duplicated across `us-east-1a` and
  `us-east-1b` from the subnet layer up.
- **Application Load Balancer** — the only public entry point. It health
  checks every target every 15 seconds and stops routing to anything that
  fails 2 checks in a row, so a dying instance is removed from rotation
  before it can serve errors to real users.
- **Auto Scaling Group** — replaces unhealthy instances automatically
  (ASG health checks are tied to the ALB's, not just EC2 status checks) and
  scales capacity up and down based on actual CPU load:
  - **Scale out** at ≥70% average CPU for 2 consecutive minutes (+1 instance)
  - **Scale in** at ≤40% average CPU for 3 consecutive minutes (−1 instance)
  - Scale-in is deliberately slower (longer cooldown, more evaluation
    periods) than scale-out — it's cheap to over-provision for a minute and
    expensive to be caught flat-footed during a spike.

## Design decisions worth explaining in an interview

**Public subnets for app instances instead of private + NAT Gateway.**
A NAT Gateway costs money every hour it exists, whether or not it moves any
traffic, plus a per-GB data processing fee. For a portfolio project that
needs to stay inside the AWS Free Tier, that's the single biggest line item
you can cut without changing the story. Security here is enforced by the
**security group**, not subnet placement: the app SG only accepts port 80
from the ALB's security group — nothing else on the internet can reach the
instances directly, NAT or no NAT. Private subnets are still provisioned
and empty, ready for RDS or an internal service, so moving to a "real"
3-tier layout later is a security-group and subnet-ID change, not a
redesign.

**Step scaling with explicit CloudWatch alarms instead of target tracking.**
AWS's target-tracking policy is one line of config and honestly easier to
run in production. It's used here as step scaling instead specifically
because it makes the two thresholds (70% out, 40% in) explicit, separate
resources you can point to and reason about individually — which is the
point of a portfolio piece.

**ELB health checks, not just EC2 status checks, on the ASG.**
EC2 status checks only catch a dead instance. ELB health checks catch a
*running* instance whose application has hung or is returning 500s — the
more common real-world failure mode — and the ASG will terminate and
replace it either way.

**IMDSv2 enforced on every instance.**
`http_tokens = "required"` in the launch template closes the SSRF-to-credential-theft
path that IMDSv1 leaves open, at zero cost.

## What "survives an outage" actually means here

| Failure                          | What happens                                                    |
|-----------------------------------|-------------------------------------------------------------------|
| One EC2 instance crashes         | ALB stops routing to it within ~30s; ASG terminates and replaces it |
| App hangs but instance stays up  | Same as above — ELB health check catches it, EC2 status check wouldn't |
| An entire AZ goes down            | ALB routes 100% of traffic to the surviving AZ; ASG launches replacement capacity there |
| Traffic spikes 3x                 | CPU crosses 70%, ASG adds capacity within ~2 minutes, up to `max_size` |
| Traffic drops back off            | CPU stays under 40% for 3 minutes, ASG removes the extra capacity — no manual cleanup |

## Usage

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars

# 2. Initialize
terraform init

# 3. Review the plan
terraform plan

# 4. Apply
terraform apply

# 5. Test it — open the ALB URL from the output
curl http://$(terraform output -raw alb_dns_name)

# 6. Tear down when done (avoid ongoing charges)
terraform destroy
```

## Cost profile

Everything here fits in the AWS Free Tier at `min_size = 2` on `t3.micro`
for a new account (750 free hours/month covers roughly one instance
running continuously — running two `t3.micro` instances 24/7 will incur a
small charge outside the free tier, on the order of a few dollars a month).
The ALB itself is **not** part of the free tier and runs roughly $16–20/mo
if left up continuously — `terraform destroy` between demos if you're cost
conscious. No NAT Gateway, no Elastic IPs sitting idle, no RDS running yet.

## File layout

| File                     | Contents                                              |
|---------------------------|--------------------------------------------------------|
| `versions.tf`             | Terraform + AWS provider version pins                 |
| `variables.tf`             | All configurable inputs, with sane defaults           |
| `vpc.tf`                   | VPC, subnets, IGW, route tables                       |
| `security_groups.tf`       | ALB and app-tier security groups                      |
| `alb.tf`                   | Load balancer, target group, listener                 |
| `asg.tf`                   | Launch template, Auto Scaling Group, scaling policies |
| `outputs.tf`               | ALB DNS name, VPC/subnet/ASG IDs                       |
| `terraform.tfvars.example` | Example variable values to copy and edit               |

## Next steps (not yet built)

- RDS (single-AZ to start, cost-optimized) in the reserved private subnets
- S3 + CloudFront for static assets
- HTTPS listener via ACM once a domain is attached
- Terraform remote state (S3 + DynamoDB lock table) — placeholder is
  commented out in `versions.tf`
