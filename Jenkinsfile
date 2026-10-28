pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {
        PATH+DOCKER = '/usr/local/bin'
        DOCKERHUB_USERNAME = 'nitindevops01'
        IMAGE_NAME = 'nitindevops01/jenkins-docker-cicd'
        CONTAINER_NAME = 'jenkins-cicd-app'
        APP_PORT = '8081'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Pulling source code from GitHub...'
                checkout scm
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                    echo "Checking Docker CLI..."
                    which docker
                    docker --version

                    echo "Checking Docker daemon..."
                    docker info
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Building Docker image..."

                    docker build \
                        -t ${IMAGE_NAME}:${BUILD_NUMBER} \
                        -t ${IMAGE_NAME}:latest \
                        .
                '''
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x

                        echo "$DH_TOKEN" | docker login \
                            -u "$DH_USER" \
                            --password-stdin

                        docker push ${IMAGE_NAME}:${BUILD_NUMBER}
                        docker push ${IMAGE_NAME}:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy Locally') {
            steps {
                sh '''
                    echo "Deploying application locally..."

                    # Remove previous demo container if present
                    docker rm -f ${CONTAINER_NAME} || true

                    # Run new container
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${APP_PORT}:80 \
                        ${IMAGE_NAME}:${BUILD_NUMBER}

                    echo "Waiting for application..."

                    for i in $(seq 1 15); do
                        if curl -fsS http://localhost:${APP_PORT}/ \
                            > /dev/null; then
                            echo "Application is responding!"
                            break
                        fi

                        if [ "$i" -eq 15 ]; then
                            echo "Application health check failed"
                            docker logs ${CONTAINER_NAME}
                            exit 1
                        fi

                        sleep 2
                    done

                    echo "Deployment successful!"
                    echo "Application: http://localhost:${APP_PORT}"

                    docker ps --filter name=${CONTAINER_NAME}
                '''
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Build, Push and Deployment completed!'
            echo 'Application URL: http://localhost:8081'
        }

        failure {
            echo 'FAILED: Check Jenkins Console Output.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}
EOF
