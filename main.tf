provider "aws" {
  shared_credentials_file = "./credentials"
  region  = "us-west-1"
  profile = "default"
}

# Create VPC
resource "aws_vpc" "prod-vpc" { 
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "production"
  }
}

# Create Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}


#Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

#Create Subnet
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1c"

  tags = {
    Name = "prod-subnet"
  }
}


resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.prod-route-table.id
}


#Create Security Group
resource "aws_security_group" "allow-web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["98.160.227.127/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Create Network Interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

}

#Create Public IP
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}


#Create Server
resource "aws_instance" "web-server-instance" {
  ami           = "ami-054965c6cd7c6e462"
  instance_type = "t2.micro"
  availability_zone = "us-west-1c"
  key_name = "Main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  provisioner "file" {
    source = "django.sh"
    destination = "/home/ec2-user/django.sh"
    }
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 777 /home/ec2-user/django.sh ",
      "sh /home/ec2-user/django.sh",
    ]
    }

    connection {
      # The default username for our AMI
      type = "ssh"
      user = "ec2-user"
      host = aws_instance.web-server-instance.public_ip
      private_key = file("Main-key.pem")
      # The connection will use the local SSH agent for authentication.
    }

  tags = {
    Name = "web-server"
  }

}
