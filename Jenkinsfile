// Declarative pipeline — Jenkins reads this file from the repo on every build.
// Flow: build image -> login to ECR -> tag & push -> deploy to EKS.
pipeline {
    agent any

    environment {
        AWS_REGION   = 'ap-south-1'
        ECR_REGISTRY = '859666866036.dkr.ecr.ap-south-1.amazonaws.com'
        IMAGE_REPO   = 'herovire-app'
        EKS_CLUSTER  = 'herovire-eks'
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

        stage('Deploy to EKS') {
            steps {
                sh '''
                    # Point kubectl at the EKS cluster (task 4.6)
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER

                    # Apply the manifests (Deployment, Service, HPA)
                    kubectl apply -f k8s/

                    # Roll out THIS build's image (unique per build) — task 4.7
                    kubectl set image deployment/$IMAGE_REPO $IMAGE_REPO=$ECR_REGISTRY/$IMAGE_REPO:$IMAGE_TAG

                    # Wait for the rolling update to finish; fail the build if it stalls
                    kubectl rollout status deployment/$IMAGE_REPO --timeout=120s
                '''
            }
            post {
                // task 4.8 — if the deploy fails, automatically roll back
                failure {
                    echo 'Deploy failed — rolling back to the previous version'
                    sh 'kubectl rollout undo deployment/$IMAGE_REPO || true'
                }
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
