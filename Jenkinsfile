// Jenkinsfile - Fixed version
pipeline {
	agent any

	environment {
		IMAGE_NAME = 'api'
		IMAGE_TAG = "${env.BUILD_NUMBER}"
	}

	stages {
		stage('Checkout') {
			steps {
				checkout scm
				echo "Building version: ${IMAGE_TAG}"
			}
		}

		stage('Test with Maven Docker') {
			steps {
				sh '''
                    echo "Running tests with Maven..."
                    docker run --rm \
                        -v "$PWD":/app \
                        -w /app \
                        maven:3.9-eclipse-temurin-17 \
                        mvn clean test
                '''
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

		stage('Deploy') {
			steps {
				sh """
                    echo "Deploying API..."

                    # Set image tag for docker-compose
                    export IMAGE_TAG=${IMAGE_TAG}

                    # Stop old containers
                    docker-compose down || true

                    # Start new containers
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
						sh '''
                            echo "Checking API health..."
                            curl -f http://localhost:8080/actuator/health || exit 1
                            echo "✅ API is healthy!"
                        '''
					}
				}
			}
		}

		stage('Cleanup') {
			steps {
				sh '''
                    echo "Cleaning up old images..."
                    docker images ${IMAGE_NAME} --format "{{.ID}} {{.Tag}}" | \
                    grep -v "latest" | tail -n +4 | awk '{print $1}' | \
                    xargs -r docker rmi || true
                '''
			}
		}
	}

	post {
		success {
			script {
				sh """
                    echo "✅ Deployment Successful!"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    echo "API URL: http://localhost:8080"
                    echo "Health: http://localhost:8080/actuator/health"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    docker ps
                """
			}
		}
		failure {
			script {
				echo "❌ Deployment failed! Check logs above."
			}
		}
	}
}