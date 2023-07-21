# repo para la imagen docker
resource "aws_ecr_repository" "app_ecr_repo" {
  name = "app-${var.stage}"
 tags = {
    Name        = "${var.stage}-repo"
    Env         = var.stage
  }
}
#
data "aws_caller_identity" "current" {

}
#upload image to ECR
resource "null_resource" "docker_packaging" {
	
	  provisioner "local-exec" {
	    command = <<EOF
	    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
	    docker tag service:latest "${aws_ecr_repository.app_ecr_repo.repository_url}:latest"
	    docker push "${aws_ecr_repository.app_ecr_repo.repository_url}:latest"
	    EOF
	  }
	

	  triggers = {
	    "run_at" = timestamp()
	  }
	

	  depends_on = [
	    aws_ecr_repository.app_ecr_repo,
	  ]
}

#politica para administrar la instancia
data "aws_iam_policy" "ec2_ssm_policy" {
    arn ="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
#documento para que ec2 pueda asumir el role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}

#documento para usar imagenes
data "aws_iam_policy_document" "ec2_ecr_pull" {
    statement {
      effect = "Allow"
      actions = [  
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                ]
     resources = [aws_ecr_repository.app_ecr_repo.arn]
    }
    statement {
      effect = "Allow"
      actions = [ "ecr:GetAuthorizationToken" ]
      resources = [ "*"]
    }
}

#politica para ecr
resource "aws_iam_policy" "ecr_policy" {
  name = "ecr-policy-${var.stage}"
  policy =  data.aws_iam_policy_document.ec2_ecr_pull.json
    tags = {
    Env         = var.stage
  }
}

#role para la instancia ec2
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role-${var.stage}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags = {
    Env         = var.stage
  }
}

# usar la politica ssm en el role
resource "aws_iam_role_policy_attachment" "ec2_ssm_policy_att" {
    role = aws_iam_role.ec2_role.name
    policy_arn = data.aws_iam_policy.ec2_ssm_policy.arn
}

# usar la politica ecr en el role
resource "aws_iam_role_policy_attachment" "ec2_ecr_policy_att" {
    role = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.ecr_policy.arn
}


# creo el instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
    role = aws_iam_role.ec2_role.name
    name = "ec2-instance-profile-${var.stage}"
    tags = {
        Env         = var.stage
    }
}

#security group para la instancia
resource "aws_security_group" "ec2_ecg" {
 name        = "ec2-sg-${var.stage}"
  description = "Grupo de seguridad ec2"
  vpc_id      = aws_vpc.vpc.id


  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
    self      = "false"
  }

  tags = {
    Env         = var.stage
  }
}

#creo la instancia
resource "aws_instance" "service" {
  ami           = "${var.ami_id}"
  instance_type =  "${var.instance_type}"
  subnet_id = aws_subnet.public_subnet.0.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  security_groups = [ "${aws_security_group.ec2_ecg.id}" ]
  tags = {
    Name        = "${var.stage}-ec2"
    Env         = var.stage
  }
    user_data = <<EOF
    #!/bin/bash
    yum update
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com
    docker pull "${aws_ecr_repository.app_ecr_repo.repository_url}:latest"
    docker tag "${aws_ecr_repository.app_ecr_repo.repository_url}:latest" service
    docker run -d -p 7080:7080 service
    EOF
}