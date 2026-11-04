pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    environment {
        DOCKER = '/usr/local/bin/docker'
        DOCKER_CONFIG = "${WORKSPACE}/.docker-config"
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
                    set -eu

                    "$DOCKER" --version
                    "$DOCKER" info

                    mkdir -p "$DOCKER_CONFIG"
                    chmod 700 "$DOCKER_CONFIG"

                    printf '{"auths":{}}\\n' > "$DOCKER_CONFIG/config.json"
                    chmod 600 "$DOCKER_CONFIG/config.json"

                    echo "Docker verification successful."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x

                        echo "$DH_TOKEN" | "$DOCKER" login \
                            -u "$DH_USER" \
                            --password-stdin

                        "$DOCKER" build \
                            -t "${IMAGE_NAME}:${BUILD_NUMBER}" \
                            -t "${IMAGE_NAME}:latest" \
                            .

                        echo "Docker image built successfully."
                    '''
                }
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
                        set -eu
                        set +x

                        echo "$DH_TOKEN" | "$DOCKER" login \
                            -u "$DH_USER" \
                            --password-stdin

                        "$DOCKER" push \
                            "${IMAGE_NAME}:${BUILD_NUMBER}"

                        "$DOCKER" push \
                            "${IMAGE_NAME}:latest"

                        "$DOCKER" logout || true

                        echo "Docker Hub push completed."
                    '''
                }
            }
        }

        stage('Pull Image from Docker Hub') {
            steps {
                sh '''
                    set -eu

                    "$DOCKER" pull "${IMAGE_NAME}:${BUILD_NUMBER}"

                    "$DOCKER" image inspect \
                        "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        --format 'Image ID: {{.Id}}'

                    echo "Image pulled successfully."
                '''
            }
        }

        stage('Deploy Locally') {
            steps {
                sh '''
                    set -eu

                    "$DOCKER" rm -f "$CONTAINER_NAME" || true

                    "$DOCKER" run -d \
                        --name "$CONTAINER_NAME" \
                        --restart unless-stopped \
                        -p "${APP_PORT}:80" \
                        "${IMAGE_NAME}:${BUILD_NUMBER}"

                    APP_READY=0

                    for i in $(seq 1 15); do
                        if curl -fsS \
                            "http://localhost:${APP_PORT}/" \
                            > /dev/null; then

                            APP_READY=1
                            echo "Application is responding!"
                            break
                        fi

                        sleep 2
                    done

                    if [ "$APP_READY" -ne 1 ]; then
                        echo "Application health check failed."
                        "$DOCKER" logs "$CONTAINER_NAME"
                        exit 1
                    fi

                    echo "Deployment successful!"
                    echo "Application: http://localhost:${APP_PORT}"

                    "$DOCKER" ps \
                        --filter "name=${CONTAINER_NAME}"
                '''
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Build, Push, Pull and Deployment completed!'
            echo 'Application URL: http://localhost:8081'
        }

        failure {
            echo 'FAILED: Check Jenkins Console Output.'
        }

        always {
            script {
                sh '''
                    if [ -n "${DOCKER_CONFIG:-}" ] && \
                       [ -d "$DOCKER_CONFIG" ]; then
                        rm -rf "$DOCKER_CONFIG"
                    fi
                '''

                echo 'Pipeline execution finished.'
            }
        }
    }
}
