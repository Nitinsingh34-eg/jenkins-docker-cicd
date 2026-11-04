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

        // 1. Checkout Source Code
        stage('Checkout') {
            steps {
                echo 'Pulling source code from GitHub...'
                checkout scm
            }
        }

        // 2. Verify Docker and Prepare Configuration
        stage('Verify Tools') {
            steps {
                sh '''
                    set -eu

                    echo "Checking Docker CLI..."
                    "$DOCKER" --version

                    echo "Checking Docker daemon..."
                    "$DOCKER" info

                    echo "Preparing isolated Docker configuration..."

                    mkdir -p "$DOCKER_CONFIG"
                    chmod 700 "$DOCKER_CONFIG"

                    # No currentContext and no credential helper
                    printf '{"auths":{}}\\n' \
                        > "$DOCKER_CONFIG/config.json"

                    chmod 600 "$DOCKER_CONFIG/config.json"

                    echo "Docker configuration prepared."
                '''
            }
        }

        // 3. Build Docker Image
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

                        echo "Logging in to Docker Hub..."

                        echo "$DH_TOKEN" | "$DOCKER" login \
                            -u "$DH_USER" \
                            --password-stdin

                        echo "Building Docker image..."

                        "$DOCKER" build \
                            -t "${IMAGE_NAME}:${BUILD_NUMBER}" \
                            -t "${IMAGE_NAME}:latest" \
                            .

                        echo "Docker image built successfully."
                    '''
                }
            }
        }

        // 4. Push Image to Docker Hub
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

                        echo "Logging in to Docker Hub..."

                        echo "$DH_TOKEN" | "$DOCKER" login \
                            -u "$DH_USER" \
                            --password-stdin

                        echo "Pushing versioned image..."

                        "$DOCKER" push \
                            "${IMAGE_NAME}:${BUILD_NUMBER}"

                        echo "Pushing latest image..."

                        "$DOCKER" push \
                            "${IMAGE_NAME}:latest"

                        echo "Image pushed successfully."

                        "$DOCKER" logout || true
                    '''
                }
            }
        }

        // 5. Deploy Locally
        stage('Deploy Locally') {
            steps {
                sh '''
                    set -eu

                    echo "Deploying application locally..."

                    # Remove previous demo container if present
                    "$DOCKER" rm -f "$CONTAINER_NAME" || true

                    # Run the newly built image
                    "$DOCKER" run -d \
                        --name "$CONTAINER_NAME" \
                        --restart unless-stopped \
                        -p "${APP_PORT}:80" \
                        "${IMAGE_NAME}:${BUILD_NUMBER}"

                    echo "Waiting for application..."

                    for i in $(seq 1 15); do

                        if curl -fsS \
                            "http://localhost:${APP_PORT}/" \
                            > /dev/null; then

                            echo "Application is responding!"
                            break
                        fi

                        if [ "$i" -eq 15 ]; then
                            echo "Application health check failed."

                            "$DOCKER" logs "$CONTAINER_NAME"

                            exit 1
                        fi

                        sleep 2
                    done

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
            echo 'SUCCESS: Build, Push and Deployment completed!'
            echo 'Application URL: http://localhost:8081'
        }

        failure {
            echo 'FAILED: Check Jenkins Console Output.'
        }

        always {
            script {
                sh '''
                    echo "Cleaning temporary Docker configuration..."

                    if [ -n "${DOCKER_CONFIG:-}" ] && \
                       [ -d "$DOCKER_CONFIG" ]; then
                        rm -rf "$DOCKER_CONFIG"
                    fi

                    echo "Pipeline cleanup completed."
                '''

                echo 'Pipeline execution finished.'
            }
        }
    }
}
