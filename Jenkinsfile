// Declarative pipeline — Jenkins reads this file from the repo on every build.
// Flow: build the Docker image -> log in to ECR -> tag & push.
pipeline {
    agent any

    environment {
        AWS_REGION   = 'ap-south-1'
        ECR_REGISTRY = '859666866036.dkr.ecr.ap-south-1.amazonaws.com'
        IMAGE_REPO   = 'herovire-app'
        // A unique, immutable tag per build (1, 2, 3, ...) plus 'latest'.
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                // Pull the repo (the same repo this Jenkinsfile lives in).
                checkout scm
            }
        }

        stage('Build image') {
            steps {
                // The app + Dockerfile live in the app/ subfolder.
                dir('app') {
                    sh 'docker build -t $IMAGE_REPO:$IMAGE_TAG .'
                }
            }
        }

        stage('Login to ECR') {
            steps {
                // Auth uses the EC2 instance's IAM role (task 1.9) — no stored keys.
                sh 'aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY'
            }
        }

        stage('Tag & Push') {
            steps {
                sh '''
                    docker tag $IMAGE_REPO:$IMAGE_TAG $ECR_REGISTRY/$IMAGE_REPO:$IMAGE_TAG
                    docker tag $IMAGE_REPO:$IMAGE_TAG $ECR_REGISTRY/$IMAGE_REPO:latest
                    docker push $ECR_REGISTRY/$IMAGE_REPO:$IMAGE_TAG
                    docker push $ECR_REGISTRY/$IMAGE_REPO:latest
                '''
            }
        }
    }

    post {
        // Clean up dangling images so the Jenkins disk doesn't fill up over time.
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "Pushed $ECR_REGISTRY/$IMAGE_REPO:$IMAGE_TAG and :latest"
        }
    }
}
