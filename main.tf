
provider "aws" {
  region = "ap-south-1"  
}

resource "aws_key_pair" "deployer" {
  key_name   = "keymumbai"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDFndPsEZEe6LKKAXRyIQJpJQ/hZJBTM5ZbOjhcAtLnEiyiOhx0bXv1HTIK3e8Q0hVUkv/Ha08UyqkSoJPljEpPx1cYSLdL1Ys1jWv8mdyNHCPovTnLRgN0zKg1bQ552BRJ/4MWbnskOAl5qX39x5QwiwkUNGqrTeMCukQAnaiuCsn0LBurlxQTKgBX6oIq/MHtb1xWJauWEPRuH7W59fUUn1EL9Ttaiu9qvlr1e1e2OGhAa7azSsfC/wNiQoqy8yUOhwdmZGPUAmlNfn2Id7DhXklMzRBH+DfgHtFzBTO8yXXSFH7R+KqQRp6mMt7snxULfndW4xi6dywJ8Uz0MczHX9/RkpInsCwludjP3x9L7yD541AAlbduOfOadjfHd/ADoAaC96z4QY7plpI+chwgIJgk73LAETg8V+nPaVP74ALhQqr7M6cy9YLGu7BklWI//K17CXyBnKPbxTm4w/OeCZliMUb0X9G2oBZeW+j2aY7i8cDtkVQ5ZDW/6GRrEe0= user@example.com"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "terraform-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-igw"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "terraform-route-table"
  }
}

resource "aws_route_table_association" "associate" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route.id
}

resource "aws_security_group" "instance_sg" {
  name        = "terraform-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-sg"
  }
}

resource "aws_instance" "example" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  availability_zone      = "ap-south-1a"  

  tags = {
    Name = "terraform-instance"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.example.public_ip} > instance_public_ip.txt"
  }
}

output "public_ip" {
  value = aws_instance.example.public_ip
}

