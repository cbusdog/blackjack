output "ec2_public_ip" {
  value = aws_instance.blackjack_server.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.blackjack_db.endpoint
}

output "rds_username" {
  value = aws_db_instance.blackjack_db.username
}
