git clone https://github.com/AnonMrNone/mutli-hybrid-cloud-1.git 
aws s3 sync F:/Hybrid-Multi-Cloud/terra/job1/mutli-hybrid-cloud-1/ s3://shubhambtesting1234/
aws s3api put-object-acl --bucket shubhambtesting1234 --key index.html --acl public-read
aws s3api put-object-acl --bucket shubhambtesting1234 --key shubham.jpg --acl public-read