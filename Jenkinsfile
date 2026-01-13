// Jenkinsfile in repo-app
pipeline {
	agent any

	environment {
		IMAGE_NAME = 'api'
		IMAGE_TAG = "${env.BUILD_NUMBER}"
		JAVA_HOME = tool name: 'JDK17', type: 'jdk'
		MAVEN_HOME = tool name: 'Maven', type: 'maven'
		PATH = "${MAVEN_HOME}/bin:${JAVA_HOME}/bin:${env.PATH}"
	}

	stages {
		stage('Checkout') {
			steps {
				checkout scm
				echo "Building version: ${IMAGE_TAG}"
			}
		}

		stage('Test') {
			steps {
				sh '''
                    echo "Running tests..."
                    mvn clean test
                '''
			}
			post {
				always {
					junit '**/target/surefire-reports/*.xml'
				}
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
                    # Keep only last 3 images
                    docker images ${IMAGE_NAME} --format "{{.ID}} {{.Tag}}" | \
                    grep -v "latest" | tail -n +4 | awk '{print $1}' | \
                    xargs -r docker rmi || true
                '''
			}
		}
	}

	post {
		success {
			echo """
            ✅ Deployment Successful!
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            Image: ${IMAGE_NAME}:${IMAGE_TAG}
            API URL: http://localhost:8080
            Health: http://localhost:8080/actuator/health
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
		}
		failure {
			echo "❌ Deployment failed! Check logs above."
		}
		always {
			sh 'docker ps'
		}
	}
}