# RDS DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name = "project-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name = "Project-DB-Subnet-Group"
  }
}
# RDS MySQL Database
resource "aws_db_instance" "main" {
  identifier        = "project-main-database"
  allocated_storage = 20
  storage_type      = "gp3"

  engine = "mysql"


  instance_class = "db.t3.micro"

  db_name  = "projectdb"
  username = "admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "Project-Main-RDS"
  }
}