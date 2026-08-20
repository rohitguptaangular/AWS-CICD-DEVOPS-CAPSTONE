# Jenkins is inside the VPC, so the cluster endpoint resolves to the private
# ENIs and the cluster SG decides access. Without this the deploy stage's
# kubectl calls just time out.
#
# The rule lives here rather than in bootstrap because it hangs off the cluster
# security group, which EKS creates. It only reads the Jenkins SG id.
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  description                  = "Jenkins to EKS API server"
  referenced_security_group_id = local.jenkins_sg_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
