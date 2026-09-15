#ec2

resource "aws_instance" "server" {
    ami= "ami-0e34b50e714a297f1"
    instance_type = "t3.micro"
    subnet_id = var.sn
    security_groups = [var.sg]

    tags =  {
        Name = "myserver"
    }  
}