pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                // Pull code from the repo automatically
                git branch: 'main', url: 'https://github.com/<username>/<repo>.git'
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