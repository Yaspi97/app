
resource "aws_instance" "jenkins" {
  ami                    = "ami-00ac45f3035ff009e"
  instance_type          = "t2.micro"
  key_name               = "Linux-VM-key"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  user_data              = <<-EOF
                              #!/bin/bash
                              export ROLE=jenkins
                              
                              # Détecter le rôle de l'instance
                              if [ "\$ROLE" == "jenkins" ]; then
                                echo "Installation de Jenkins..."

                                # Mettre à jour l'index des paquets
                                sudo apt update -y

                                # Installer AdoptOpenJDK 17
                                wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
                                echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptopenjdk.list
                                sudo apt update -y
                                sudo apt install adoptopenjdk-17-hotspot -y
                                java -version

                                # Installer Jenkins
                                curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
                                echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
                                sudo apt update -y
                                sudo apt install jenkins -y
                                sudo systemctl start jenkins
                                sudo systemctl enable jenkins

                                # Installer Docker
                                sudo apt update -y
                                sudo apt install docker.io -y
                                sudo usermod -aG docker ubuntu
                                sudo usermod -aG docker jenkins
                                sudo systemctl start docker
                                sudo systemctl enable docker

                                # Installer Trivy
                                sudo apt install wget apt-transport-https gnupg lsb-release -y
                                wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
                                echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
                                sudo apt update -y
                                sudo apt install trivy -y

                                # Afficher le statut de Jenkins
                                sudo systemctl status jenkins
                              fi
                            EOF

  tags = {
    Name = "Jenkins-Instance"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_instance" "sonarqube" {
  ami                    = "ami-00ac45f3035ff009e"
  instance_type          = "t2.micro"
  key_name               = "Linux-VM-key"
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  user_data              = <<-EOF
                              #!/bin/bash
                              export ROLE=sonarqube
                              
                              # Détecter le rôle de l'instance
                              if [ "\$ROLE" == "sonarqube" ]; then
                                echo "Installation de SonarQube..."

                                # Mettre à jour l'index des paquets
                                sudo apt update -y

                                # Installer AdoptOpenJDK 17
                                wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | sudo apt-key add -
                                echo "deb https://adoptopenjdk.jfrog.io/adoptopenjdk/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptopenjdk.list
                                sudo apt update -y
                                sudo apt install adoptopenjdk-17-hotspot -y
                                java -version

                                # Ajouter l'utilisateur SonarQube
                                sudo adduser --system --no-create-home --group --disabled-login sonar

                                # Télécharger et installer SonarQube
                                wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.8.0.63668.zip
                                sudo apt install unzip -y
                                sudo unzip sonarqube-9.8.0.63668.zip -d /opt
                                sudo mv /opt/sonarqube-9.8.0.63668 /opt/sonarqube
                                sudo chown -R sonar:sonar /opt/sonarqube

                                # Configurer SonarQube en tant que service
                                sudo bash -c 'cat << EOF > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=simple
User=sonar
Group=sonar
PermissionsStartOnly=true
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
StandardOutput=syslog
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=5
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

                                # Démarrer et activer le service SonarQube
                                sudo systemctl start sonarqube
                                sudo systemctl enable sonarqube

                                # Afficher le statut de SonarQube
                                sudo systemctl status sonarqube
                              fi
                            EOF

  tags = {
    Name = "SonarQube-Instance"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Security group for Jenkins"
  vpc_id      = "vpc-06122b56c5128e275"

  ingress = [
    for port in [22, 80, 443, 8080, 9000, 3000] : {
      description      = "Allow inbound traffic on port ${port}"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "Allow all outbound traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube_sg"
  description = "Security group for SonarQube"
  vpc_id      = "vpc-06122b56c5128e275"

  ingress = [
    for port in [22, 80, 443, 8080, 9000, 3000] : {
      description      = "Allow inbound traffic on port ${port}"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "Allow all outbound traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}
