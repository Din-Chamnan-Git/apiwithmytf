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
        string(name: 'GHCR_OWNER', defaultValue: 'din-chamnan-git', description: 'GitHub owner/org for GHCR image')
        string(name: 'GHCR_USERNAME', defaultValue: 'Din-Chamnan-Git', description: 'GitHub username used to authenticate to GHCR')
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
                    if [ -f "app/$APP_PATH/pom.xml" ]; then
                      RESOLVED_APP_PATH="$APP_PATH"
                    elif [ -f "app/pom.xml" ]; then
                      RESOLVED_APP_PATH="."
                    elif [ -f "app/api/pom.xml" ]; then
                      RESOLVED_APP_PATH="api"
                    else
                      echo "ERROR: Could not find pom.xml in app/$APP_PATH, app/, or app/api/"
                      exit 1
                    fi
                    echo "Resolved app path: $RESOLVED_APP_PATH"

                    if command -v ansible-playbook >/dev/null 2>&1; then
                      ansible-playbook --version | head -n 1
                    else
                      echo "ansible-playbook not found on agent; pipeline will bootstrap a local venv in deploy stage."
                      command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required to bootstrap ansible."; exit 1; }
                    fi

                    if [ -f "app/$RESOLVED_APP_PATH/mvnw" ]; then
                      echo "Using Maven Wrapper: app/$RESOLVED_APP_PATH/mvnw"
                    elif command -v mvn >/dev/null 2>&1; then
                      mvn --version | head -n 1
                    else
                      echo "ERROR: Maven not found (neither app/$RESOLVED_APP_PATH/mvnw nor system mvn)."
                      exit 1
                    fi
                '''
            }
        }

        stage('Build And Push Image (Jib)') {
            steps {
                withCredentials([string(credentialsId: 'github-pat-global', variable: 'GHCR_TOKEN')]) {
                    sh '''
                        set -e

                        if [ -f "app/$APP_PATH/pom.xml" ]; then
                          RESOLVED_APP_PATH="$APP_PATH"
                        elif [ -f "app/pom.xml" ]; then
                          RESOLVED_APP_PATH="."
                        elif [ -f "app/api/pom.xml" ]; then
                          RESOLVED_APP_PATH="api"
                        else
                          echo "ERROR: Could not find pom.xml in app/$APP_PATH, app/, or app/api/"
                          exit 1
                        fi

                        cd "app/$RESOLVED_APP_PATH"
                        if [ -f "./mvnw" ]; then
                          chmod +x ./mvnw
                          MVN="./mvnw"
                        else
                          MVN="mvn"
                        fi
                        IMAGE_REPO_LOWER="$(echo "$IMAGE_REPO" | tr '[:upper:]' '[:lower:]')"
                        IMAGE_FULL_LOWER="$IMAGE_REPO_LOWER:$IMAGE_TAG"

                        "$MVN" -B -DskipTests com.google.cloud.tools:jib-maven-plugin:3.4.3:build \
                          -Djib.to.image="$IMAGE_FULL_LOWER" \
                          -Djib.to.auth.username="$GHCR_USERNAME" \
                          -Djib.to.auth.password="$GHCR_TOKEN" \
                          -Djib.to.tags=latest
                    '''
                }
            }
        }

        stage('Deploy With Ansible') {
            steps {
                sshagent(credentials: ['app-server-ssh']) {
                    withCredentials([string(credentialsId: 'github-pat-global', variable: 'GHCR_TOKEN')]) {
                        sh '''
                            set -e

                            if [ -f "app/$APP_PATH/docker-compose.yml" ]; then
                              RESOLVED_APP_PATH="$APP_PATH"
                            elif [ -f "app/docker-compose.yml" ]; then
                              RESOLVED_APP_PATH="."
                            elif [ -f "app/api/docker-compose.yml" ]; then
                              RESOLVED_APP_PATH="api"
                            else
                              echo "ERROR: Could not find docker-compose.yml in app/$APP_PATH, app/, or app/api/"
                              exit 1
                            fi

                            cp "app/$RESOLVED_APP_PATH/docker-compose.yml" /tmp/docker-compose.yml
                            IMAGE_REPO_LOWER="$(echo "$IMAGE_REPO" | tr '[:upper:]' '[:lower:]')"
                            sed -i "s|image: api:\\${IMAGE_TAG:-latest}|image: ${IMAGE_REPO_LOWER}:\\${IMAGE_TAG:-latest}|g" /tmp/docker-compose.yml

                            cd "infra/$INFRA_ANSIBLE_DIR"
                            export GHCR_USER="$GHCR_USERNAME"
                            export GHCR_TOKEN="$GHCR_TOKEN"
                            if command -v ansible-playbook >/dev/null 2>&1; then
                                ANSIBLE_BIN="ansible-playbook"
                            else
                                python3 -m venv .ansible-venv
                                . .ansible-venv/bin/activate
                                pip install --upgrade pip
                                pip install "ansible-core>=2.16,<2.18"
                                ANSIBLE_BIN=".ansible-venv/bin/ansible-playbook"
                            fi

                            ANSIBLE_HOST_KEY_CHECKING=False "$ANSIBLE_BIN" \
                                -i "$ANSIBLE_INVENTORY" \
                                "$ANSIBLE_PLAYBOOK" \
                                --extra-vars "environment=$ENVIRONMENT version=$IMAGE_TAG image_name=$IMAGE_REPO_LOWER target_hosts=$TARGET_HOSTS"
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
