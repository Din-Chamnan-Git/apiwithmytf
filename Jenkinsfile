pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        string(name: 'APP_REPO_URL', defaultValue: 'git@github.com:Din-Chamnan-Git/apiwithmytf.git', description: 'Git URL for app repository')
        string(name: 'APP_REPO_BRANCH', defaultValue: 'main', description: 'App repository branch')
        string(name: 'INFRA_REPO_URL', defaultValue: 'git@github.com:Din-Chamnan-Git/mytf.git', description: 'Git URL for terraform/ansible repository')
        string(name: 'INFRA_REPO_BRANCH', defaultValue: 'main', description: 'Infra repository branch')
        string(name: 'GIT_CREDENTIALS_ID', defaultValue: 'deploy-ssh-key', description: 'Jenkins Git SSH credentials ID')
        string(name: 'APP_PATH', defaultValue: 'api', description: 'Path to app Docker context inside app repo')
        string(name: 'INFRA_ANSIBLE_DIR', defaultValue: 'terraform_with_hetzner/ansible', description: 'Path to ansible directory inside infra repo')
        string(name: 'GHCR_OWNER', defaultValue: 'Din-Chamnan-Git', description: 'GitHub owner/org for GHCR image')
        string(name: 'IMAGE_NAME', defaultValue: 'api', description: 'Docker image name')
        string(name: 'ENVIRONMENT', defaultValue: 'dev', description: 'Deployment environment')
        string(name: 'ANSIBLE_INVENTORY', defaultValue: 'inventories/dev/inventory.ini', description: 'Ansible inventory path')
        string(name: 'ANSIBLE_PLAYBOOK', defaultValue: 'playbooks/deploy-app.yml', description: 'Ansible playbook path')
        string(name: 'TARGET_HOSTS', defaultValue: 'webservers', description: 'Ansible target hosts/group')
    }

    environment {
        REGISTRY = 'ghcr.io'
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE_REPO = "${REGISTRY}/${params.GHCR_OWNER}/${params.IMAGE_NAME}"
        IMAGE_FULL = "${IMAGE_REPO}:${IMAGE_TAG}"
        IMAGE_LATEST = "${IMAGE_REPO}:latest"
    }

    stages {
        stage('Checkout Repositories') {
            steps {
                deleteDir()
                dir('app') {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${params.APP_REPO_BRANCH}"]],
                        userRemoteConfigs: [[url: "${params.APP_REPO_URL}", credentialsId: "${params.GIT_CREDENTIALS_ID}"]]
                    ])
                }
                dir('infra') {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${params.INFRA_REPO_BRANCH}"]],
                        userRemoteConfigs: [[url: "${params.INFRA_REPO_URL}", credentialsId: "${params.GIT_CREDENTIALS_ID}"]]
                    ])
                }
            }
        }

        stage('Precheck Tools') {
            steps {
                sh '''
                    set -e
                    command -v ansible-playbook >/dev/null 2>&1 || { echo "ERROR: ansible-playbook is not installed on this Jenkins agent."; exit 1; }
                    ansible-playbook --version | head -n 1

                    if [ -x "app/$APP_PATH/mvnw" ]; then
                      echo "Using Maven Wrapper: app/$APP_PATH/mvnw"
                    elif command -v mvn >/dev/null 2>&1; then
                      mvn --version | head -n 1
                    else
                      echo "ERROR: Maven not found (neither app/$APP_PATH/mvnw nor system mvn)."
                      exit 1
                    fi
                '''
            }
        }

        stage('Build And Push Image (Jib)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-pat-global', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    dir("app/${params.APP_PATH}") {
                        sh '''
                            set -e

                            if [ -x "./mvnw" ]; then
                              MVN="./mvnw"
                            else
                              MVN="mvn"
                            fi

                            "$MVN" -B -DskipTests com.google.cloud.tools:jib-maven-plugin:3.4.3:build \
                              -Djib.to.image="$IMAGE_FULL" \
                              -Djib.to.auth.username="$GHCR_USER" \
                              -Djib.to.auth.password="$GHCR_TOKEN" \
                              -Djib.to.tags=latest
                        '''
                    }
                }
            }
        }

        stage('Deploy With Ansible') {
            steps {
                sshagent(credentials: ['app-server-ssh']) {
                    withCredentials([usernamePassword(credentialsId: 'github-pat-global', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                        sh '''
                            set -e
                            cp "app/$APP_PATH/docker-compose.yml" /tmp/docker-compose.yml
                            sed -i "s|image: api:\\${IMAGE_TAG:-latest}|image: ${IMAGE_REPO}:\\${IMAGE_TAG:-latest}|g" /tmp/docker-compose.yml

                            cd "infra/$INFRA_ANSIBLE_DIR"
                            ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
                                -i "$ANSIBLE_INVENTORY" \
                                "$ANSIBLE_PLAYBOOK" \
                                --extra-vars "environment=$ENVIRONMENT version=$IMAGE_TAG image_name=$IMAGE_REPO target_hosts=$TARGET_HOSTS"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished: ${currentBuild.currentResult}"
        }
        success {
            echo "Deploy success: ${IMAGE_FULL}"
        }
        failure {
            echo 'Deploy failed.'
        }
    }
}
