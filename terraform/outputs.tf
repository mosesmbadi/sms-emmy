# Output values for SMS Emmy Infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.sms_emmy_vpc.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.sms_emmy_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sms_emmy_instance.private_ip
}

output "ssh_connection_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i sms_emmy_key.pem ${var.admin_username}@${aws_eip.sms_emmy_eip.public_ip}"
}

output "application_url" {
  description = "URL to access the SMS Emmy application"
  value       = "http://${aws_eip.sms_emmy_eip.public_ip}:5000"
}

output "ssh_private_key" {
  description = "Private SSH key to connect to the EC2 instance"
  value       = tls_private_key.sms_emmy_ssh.private_key_pem
  sensitive   = true
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sms_emmy_instance.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.sms_emmy_vpc.cidr_block
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.sms_emmy_public_subnet.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.sms_emmy_sg.id
}

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.sms_emmy_key_pair.key_name
}

output "elastic_ip_address" {
  description = "Elastic IP address (static)"
  value       = aws_eip.sms_emmy_eip.public_ip
}
