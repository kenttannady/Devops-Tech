resource "aws_instance" "secure_vm" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "HardenedInstance"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.1.100/32"] # Office IP
  }
}
