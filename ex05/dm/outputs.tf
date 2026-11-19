output "zookeeper_public_ip" {
  description = "Public IP of the ZooKeeper instance"
  value       = aws_instance.zookeeper.public_ip
}

output "app_public_ips" {
  description = "Public IPs of the five auction nodes"
  value       = aws_instance.app[*].public_ip
}

output "zookeeper_private_ip" {
  description = "Private IP the app nodes use to reach ZooKeeper"
  value       = aws_instance.zookeeper.private_ip
}
