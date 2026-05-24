# HelloWorld Spring Boot

This repository contains a minimal Spring Boot (Spring MVC) application exposing a Hello World API and a GitHub Actions CI/CD pipeline that builds the project and deploys it to an AWS EC2 instance over SSH.

Endpoints
- GET /api/hello -> returns "Hello World"

How it works
- The GitHub Actions workflow (on push to main) builds the project with Maven and produces a runnable jar.
- The workflow then copies the jar to your EC2 instance using SCP and runs remote commands over SSH to install/start a systemd service that runs the jar.

Prerequisites on EC2
- An EC2 Linux instance (Ubuntu/Debian recommended) with:
  - OpenJDK 17 installed (or another JDK matching the build)
    - Example: sudo apt update && sudo apt install -y openjdk-17-jre
  - A user with sudo privileges (we assume this is the user you set in the secret `EC2_USER`)
  - The runner's public key (from which you create the GitHub secret with the private key) added to that user's ~/.ssh/authorized_keys
  - Ensure port 22 is open (for SSH) and port 8080 open if you want to access the app directly

GitHub Secrets required
- EC2_HOST: IP or hostname of the EC2 instance
- EC2_USER: username on the EC2 instance (e.g., ubuntu)
- EC2_SSH_KEY: private SSH key that the workflow will use to connect (newline characters must be preserved)
- EC2_SSH_PORT: optional (defaults to 22)
- REMOTE_PATH: optional (where to put the uploaded jar; default: /home/${{ secrets.EC2_USER }}/helloworld)

Notes about the systemd service
- The workflow will place the jar under /opt/helloworld/app.jar and create a systemd unit at /etc/systemd/system/helloworld.service which runs:
  ExecStart=/usr/bin/java -jar /opt/helloworld/app.jar
- The deployed user must have sudo privileges because the workflow uses sudo to install the systemd unit and start/enable the service.

How to test locally
1. Build with Maven:
   mvn -B package
2. Run the jar:
   java -jar target/helloworld-0.0.1-SNAPSHOT.jar
3. Call the API:
   curl http://localhost:8080/api/hello

Customizing
- You can change the Java version or Spring Boot version in `pom.xml`.
- If you prefer to use an alternative deployment (ECS, EKS, CodeDeploy), adjust the workflow accordingly.

