# Get Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_1.id

  vpc_security_group_ids = [var.ec2_security_group_id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Project 2 - Application Server" > /var/www/html/index.html
  EOF

  tags = {
    Name = "Project-App-EC2"
  }
}
# Attach EC2 Instance to ALB Target Group
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 80
}