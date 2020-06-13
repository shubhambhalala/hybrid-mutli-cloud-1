#To declare which provider we want
provider "aws" {
	region  = "ap-south-1"
}

#To create security group with http and ssh
resource "aws_security_group" "webos-sg" {
  name        = "webos-sg"
  description = "allow ssh and http traffic"

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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
#To create EBS Volume
resource "aws_ebs_volume" "web" {
	availability_zone  = "ap-south-1a"
	type	   = "gp2"
	size		   = 1
	tags		   = {
		Name = "webebs"
	}
}
#To create instance 
resource "aws_instance" "webosec2" {
	ami		   = "ami-005956c5f0f757d37"
	availability_zone  = "ap-south-1a"
	instance_type	   = "t2.micro"
	key_name	   = "amzlinux"     #"${aws_key_pair.generated_key.key_name}"
	security_groups	   = ["${aws_security_group.webos-sg.name}"]
	user_data	   = <<-EOF
			       #! /bin/bash
			       sudo su - root
			       yum install httpd -y
			       yum install php -y
			       yum install git -y
			       yum update -y
			       service httpd start
			       chkconfig --add httpd


	EOF
	tags		   = {
		Name = "webserver-php"
	}
}
#To attach the EBS volume
resource "aws_volume_attachment" "ebs_att" {
	device_name  = "/dev/sdc"
	volume_id    = "${aws_ebs_volume.web.id}"
	instance_id  = "${aws_instance.webosec2.id}"
	force_detach = true
}
#To format mount and download git data into dir
resource "null_resource" "format_git" {

	connection {
		type  = "ssh"
		user  = "ec2-user"
		private_key  = file("F:/Hybrid-Multi-Cloud/terra/job1/amzlinux.pem")
		host  = aws_instance.webosec2.public_ip
	}
	provisioner "remote-exec" {
		inline = [ 
			     "sudo mkfs -t ext4 /dev/xvdc",
			     "sudo mount /dev/xvdc /var/www/html",
			     "sudo rm -rf /var/www/html/*",
			     "sudo git clone https://github.com/AnonMrNone/mutli-hybrid-cloud-1.git /var/www/html/",
		]
		
	}
	depends_on  = ["aws_volume_attachment.ebs_att"]
}
#To create S3 bucket
resource "aws_s3_bucket" "shubhambtesting1234" {
  bucket = "shubhambtesting1234"
  acl    = "public-read"
  force_destroy  = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://shubhambtesting1234"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
#To upload data to S3 bucket
resource "null_resource" "remove_and_upload_to_s3" {
  provisioner "local-exec" {
    command = "F:/Hybrid-Multi-Cloud/terra/job1/s3update.bat"
  }
  depends_on  = ["aws_s3_bucket.shubhambtesting1234"]
}


# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "distribution" {
    origin {
        domain_name = "${aws_s3_bucket.shubhambtesting1234.bucket_regional_domain_name}"
        origin_id = "S3-${aws_s3_bucket.shubhambtesting1234.bucket}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
    # By default, show index.html file
    default_root_object = "index.html"
    enabled = true

    # If there is a 404, return index.html with a HTTP 200 Response
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.html"
    }

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.shubhambtesting1234.bucket}"

        #Not Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
	    cookies {
		forward = "none"
	    }
            
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    # Distributes content to all
    price_class = "PriceClass_All"

    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
output "cloudfront_ip_addr" {
  value = aws_cloudfront_distribution.distribution.domain_name
}
