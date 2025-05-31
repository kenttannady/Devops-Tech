Deployment Instructions
==========================
For Local (VirtualBox) Deployment
1. Initialize Terraform:

	terraform init

2. Apply the configuration:

	terraform apply -var="environment=local"

3. Run Ansible playbook:

	ansible-playbook -i inventory_local.ini main.yml

4. Access the application:

	Public NGINX: http://localhost:8080

	Grafana: http://localhost:3000 (admin/admin)


For AWS Deployment
==============================
1.  Initialize Terraform:

	terraform init

2.  Apply the configuration:


	terraform apply -var="environment=aws"

3.  Upload static content to S3:

	aws s3 sync ./static-content/ s3://$(terraform output -raw s3_bucket_name)/

4.  Run Ansible playbook:

	ansible-playbook -i inventory_aws.ini main.yml

5.  Configure VPN:

	Download the VPN client config from AWS Console
	Connect using OpenVPN client

6.  Access the application:
	echo "Application URL: http://$(terraform output -raw lb_dns)"
	echo "CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home"