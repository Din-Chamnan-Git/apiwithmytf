pipeline {
	agent any

	environment {
		APP_NAME = 'spring-boot-api'
		ANSIBLE_INVENTORY = credentials('ANSIBLE_INVENTORY')
		BOT_TOKEN = credentials('TELEGRAM_BOT_TOKEN')
		CHAT_ID = credentials('TELEGRAM_CHAT_ID')
		ENVIRONMENT = 'dev'
		APP_DIR = '/opt/spring-boot-api'
	}

	stages {
		stage('Checkout Code') {
			steps {
				echo '📥 Checking out application code...'
				checkout scm
			}
		}

		stage('Git Info') {
			steps {
				script {
					env.GIT_AUTHOR = sh(script: "git log -1 --pretty=%an", returnStdout: true).trim()
					env.GIT_MESSAGE = sh(script: "git log -1 --pretty=%s", returnStdout: true).trim()
					env.GIT_TIME = sh(script: "date '+%Y-%m-%d %H:%M:%S'", returnStdout: true).trim()
					env.GIT_BRANCH = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
					env.GIT_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
				}
			}
		}

		stage('Build with Maven') {
			steps {
				echo '🔨 Building Spring Boot application...'
				sh '''
					mvn clean package -DskipTests
				'''
			}
		}

		stage('Run Tests') {
			steps {
				echo '✅ Running unit tests...'
				sh '''
					mvn test
				'''
			}
		}

		stage('Build Docker Image') {
			steps {
				echo '🐳 Building Docker image...'
				sh '''
					docker build -t ${APP_NAME}:${GIT_COMMIT} .
					docker tag ${APP_NAME}:${GIT_COMMIT} ${APP_NAME}:latest
				'''
			}
		}

		stage('Deploy to Server') {
			steps {
				echo '🚀 Deploying to server using Ansible...'
				sh '''
					# Copy application files to Ansible directory
					mkdir -p /tmp/app-deploy
					cp -r src pom.xml .mvn Dockerfile docker-compose.yml /tmp/app-deploy/

					# Run Ansible deployment playbook
					ansible-playbook /home/nan/infra/terraform_with_hetzner/ansible/playbooks/deploy-jenkins-app.yml \
						-i ${ANSIBLE_INVENTORY} \
						-e "git_commit_sha=${GIT_COMMIT}" \
						-e "git_branch_name=${GIT_BRANCH}" \
						-e "git_author_name=${GIT_AUTHOR}" \
						-e "git_commit_message=${GIT_MESSAGE}" \
						--extra-vars "app_source_dir=/tmp/app-deploy"
				'''
			}
		}
	}

	post {
		success {
			echo '✅ Telegram notification sent!'
			sh '''
				curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
				-d chat_id=${CHAT_ID} \
				-d parse_mode=Markdown \
				-d text="✅ *Java App Build & Deploy SUCCESS* 🚀
App: ${APP_NAME}
Job: ${JOB_NAME}
Build: #${BUILD_NUMBER}
Branch: ${GIT_BRANCH}
Commit: ${GIT_COMMIT}
Author: ${GIT_AUTHOR}
Message: ${GIT_MESSAGE}
Time: ${GIT_TIME}
Environment: ${ENVIRONMENT}
Status: Application deployed and running
URL: ${BUILD_URL}"
			'''
		}

		failure {
			echo '❌ Build failed! Sending notification...'
			sh '''
				curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
				-d chat_id=${CHAT_ID} \
				-d parse_mode=Markdown \
				-d text="❌ *Java App Build FAILED* 🔥
App: ${APP_NAME}
Job: ${JOB_NAME}
Build: #${BUILD_NUMBER}
Branch: ${GIT_BRANCH}
Commit: ${GIT_COMMIT}
Author: ${GIT_AUTHOR}
Message: ${GIT_MESSAGE}
Time: ${GIT_TIME}
Logs: ${BUILD_URL}console"
			'''
		}

		always {
			echo '🧹 Cleaning up Docker artifacts...'
			sh 'docker system prune -f || true'
			cleanWs()
		}
	}
}

