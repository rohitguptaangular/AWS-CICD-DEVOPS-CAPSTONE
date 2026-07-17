pipeline {
    agent any

    environment {
        AWS_REGION   = 'ap-south-1'
        ECR_REGISTRY = '376129434099.dkr.ecr.ap-south-1.amazonaws.com'
        IMAGE_REPO   = 'herovire-app'
        EKS_CLUSTER  = 'herovire-eks'
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build image') {
            steps {
                dir('app') {
                    sh 'docker build -t $IMAGE_REPO:$IMAGE_TAG .'
                }
            }
        }

        stage('Login to ECR') {
            steps {
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

        stage('Deploy to EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER
                    kubectl apply -f k8s/
                    kubectl set image deployment/$IMAGE_REPO $IMAGE_REPO=$ECR_REGISTRY/$IMAGE_REPO:$IMAGE_TAG
                    kubectl rollout status deployment/$IMAGE_REPO --timeout=120s
                '''
            }
            post {
                failure {
                    sh 'kubectl rollout undo deployment/$IMAGE_REPO || true'
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        failure {
            mail to: 'eiron.rohit@gmail.com',
                 subject: "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                 body: "Pipeline failed. Details: ${env.BUILD_URL}"
        }
    }
}
