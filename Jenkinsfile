pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                // Pull code from the repo automatically
                git branch: 'main', url: 'git@github.com:Din-Chamnan-Git/apiwithmytf.git'
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
        success {
            echo 'Tests passed! ✅'
        }
        failure {
            echo 'Tests failed! ❌'
        }
    }
}