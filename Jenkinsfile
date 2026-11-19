
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(
            name: 'APPLY_INFRA',
            defaultValue: false,
            description: 'Apply Terraform infrastructure changes?'
        )
    }

    environment {
        AWS_REGION       = 'ap-southeast-2'
        AWS_ACCOUNT_ID   = '591109179789'
        ECR_REPO         = 'hitech-ui'
        EKS_CLUSTER      = 'hitech-eks'

        GITOPS_REPO      = 'https://github.com/mbniketh5/Hitech-UI.git'
        GITOPS_BRANCH    = 'main'
    }

    stages {

        // 1. GitHub Source Code
        stage('Git Checkout') {
            steps {
                echo 'Checking out Hitech-UI source code'
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        // 2. Terraform Infrastructure
        stage('Terraform Init') {
            steps {
                sh '''
                    terraform -chdir=terraform init
                '''
            }
        }

        stage('Terraform Validate') {
            steps {
                sh '''
                    terraform -chdir=terraform validate
                '''
            }
        }

        stage('Terraform Plan - VPC, SG, EC2') {
            steps {
                sh '''
                    terraform -chdir=terraform plan \
                    -out=tfplan
                '''
            }
        }

        // 3. Optional infrastructure deployment
        stage('Terraform Apply') {
            when {
                expression {
                    return params.APPLY_INFRA
                }
            }
            steps {
                input message: 'Approve Terraform infrastructure changes?',
                      ok: 'Apply Infrastructure'

                sh '''
                    terraform -chdir=terraform apply -auto-approve tfplan
                '''
            }
        }
        //set URI Image
        stage('Set Image URI') {
            steps {
              script {
            env.IMAGE_URI = "${591109179789}.dkr.ecr.${ap-southeast-2}.amazonaws.com/${hitech-ui}:${v2}"

            echo "Docker Image URI: ${env.IMAGE_URI}"
             }
           }
        }
        // 4. Docker Build
        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                    -t hitech-ui:${BUILD_NUMBER} .
                '''
            }
        }

        // 5. Docker Image Verification
        stage('Docker Image Check') {
            steps {
                sh '''
                    docker images hitech-ui:${BUILD_NUMBER}
                '''
            }
        }

        // 6. AWS Authentication
        stage('AWS Authentication') {
            steps {
                sh '''
                    aws sts get-caller-identity
                '''
            }
        }

        // 7. ECR Login
        stage('ECR Login') {
            steps {
                sh '''
                    aws ecr get-login-password \
                    --region ${AWS_REGION} |
                    docker login \
                    --username AWS \
                    --password-stdin \
                    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                '''
            }
        }

        // 8. Docker Tag
        stage('Docker Tag') {
            steps {
                sh '''
                    docker tag \
                    hitech-ui:${BUILD_NUMBER} \
                    ${IMAGE_URI}
                '''
            }
        }

        // 9. Push image to ECR
        stage('Push Image to ECR') {
            steps {
                sh '''
                    docker push ${IMAGE_URI}
                '''
            }
        }

        // 10. Verify EKS
        stage('EKS Cluster Verification') {
            steps {
                sh '''
                    aws eks describe-cluster \
                    --name ${EKS_CLUSTER} \
                    --region ${AWS_REGION} \
                    --query "cluster.status" \
                    --output text
                '''
            }
        }

        // 11. GitOps Repository Checkout
        stage('GitOps Checkout') {
            steps {
                dir('gitops') {
                    git branch: "${GITOPS_BRANCH}",
                        credentialsId: 'github-credentials',
                        url: "${GITOPS_REPO}"
                }
            }
        }

        // 12. Update Kubernetes Image
        stage('Update Kubernetes Manifest') {
            steps {
                dir('gitops') {
                    sh '''
                        yq -i \
                        '(.spec.template.spec.containers[] |
                        select(.name == "hitech-ui").image) = strenv(IMAGE_URI)' \
                        k8s/deployment.yaml

                        cat k8s/deployment.yaml
                    '''
                }
            }
        }

        // 13. GitOps Commit and Push
        stage('GitOps Commit and Push') {
            steps {
                dir('gitops') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'github-credentials',
                            usernameVariable: 'GIT_USER',
                            passwordVariable: 'GIT_TOKEN'
                        )
                    ]) {
                        sh '''
                            git config user.name "Jenkins CI"
                            git config user.email "jenkins@example.com"

                            git add k8s/deployment.yaml

                            if ! git diff --cached --quiet; then
                                git -c http.extraheader="AUTHORIZATION: basic $(printf '%s' "$GIT_USER:$GIT_TOKEN" | base64 -w0)" \
                                commit -m "Deploy Hitech-UI image ${BUILD_NUMBER}"

                                git -c http.extraheader="AUTHORIZATION: basic $(printf '%s' "$GIT_USER:$GIT_TOKEN" | base64 -w0)" \
                                push origin HEAD:${GITOPS_BRANCH}
                            else
                                echo "No manifest changes to commit"
                            fi
                        '''
                    }
                }
            }
        }

        // 14. Deployment status
        stage('Argo CD Deployment Trigger') {
            steps {
                echo 'GitOps manifest updated.'
                echo 'Argo CD will detect the new image and synchronize EKS.'
            }
        }
    }

    post {
        success {
            echo 'Hitech-UI CI/CD Pipeline Completed Successfully!'
            echo "Docker Image: ${IMAGE_URI}"
        }

        failure {
            echo 'Hitech-UI Pipeline Failed. Check Jenkins Console Output.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}

