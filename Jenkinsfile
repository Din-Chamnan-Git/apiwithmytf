pipeline {
	agent any

	environment {
		IMAGE_NAME = 'api'
		IMAGE_TAG = "${env.BUILD_NUMBER}"
		API_PORT = '8081'  // ← API runs on 8081

		BOT_TOKEN = credentials('TELEGRAM_BOT_TOKEN')
		CHAT_ID  = credentials('TELEGRAM_CHAT_ID')
	}

	stages {
		stage('Checkout') {
			steps {
				checkout scm
				echo "Building version: ${IMAGE_TAG}"
			}
		}

		stage('Build Docker Image') {
			steps {
				sh """
                    echo "Building Docker image..."
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                """
			}
		}

		stage('Stop Old Containers') {
			steps {
				sh """
                    echo "Stopping old API containers..."
                    docker stop api 2>/dev/null || true
                    docker rm api 2>/dev/null || true
                    docker-compose down 2>/dev/null || true
                    sleep 2
                """
			}
		}

		stage('Deploy') {
			steps {
				sh """
                    echo "Deploying API on port ${API_PORT}..."
                    export IMAGE_TAG=${IMAGE_TAG}
                    docker-compose up -d

                    echo "Waiting for API to be ready..."
                    sleep 15
                """
			}
		}

		stage('Health Check') {
			steps {
				script {
					retry(5) {
						sleep 5
						sh """
                            echo "Checking API health on port ${API_PORT}..."
                            curl -f http://localhost:${API_PORT}/actuator/health
                            echo "✅ API is healthy!"
                        """
					}
				}
			}
		}

		stage('Show Status') {
			steps {
				sh """
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "✅ Deployment Successful!"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    echo "API URL: http://localhost:${API_PORT}"
                    echo "Health: http://localhost:${API_PORT}/actuator/health"
                    echo "Jenkins: http://localhost:8080"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    docker-compose ps
                """
			}
		}

		stage('Cleanup Old Images') {
			steps {
				sh '''
                    echo "Cleaning up old images..."
                    docker image prune -f
                    docker images ${IMAGE_NAME} --format "{{.ID}} {{.Tag}}" | \
                    grep -v "latest" | tail -n +4 | awk '{print $1}' | \
                    xargs -r docker rmi -f || true
                '''
			}
		}
	}

	post {
		success {
			script {
				sh """
            curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
            -d chat_id=${CHAT_ID} \
            -d parse_mode=Markdown \
            -d text="✅ *DEPLOY SUCCESS* 🚀
				App: ${IMAGE_NAME}
				Build: #${BUILD_NUMBER}
				Image: ${IMAGE_NAME}:${IMAGE_TAG}
				Port: ${API_PORT}
				Health: http://localhost:${API_PORT}/actuator/health
				Job: ${JOB_NAME}
				URL: ${BUILD_URL}"
							"""
			}
		}
		failure {
			script {
				sh """
            curl -s -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage \
            -d chat_id=${CHAT_ID} \
            -d parse_mode=Markdown \
            -d text="❌ *DEPLOY FAILED* 🔥
				App: ${IMAGE_NAME}
				Build: #${BUILD_NUMBER}
				Job: ${JOB_NAME}
				Logs: ${BUILD_URL}console"
							"""
						}

						sh '''
						docker ps
						docker logs api --tail 50 2>/dev/null || true
					'''
					}
				}

	}