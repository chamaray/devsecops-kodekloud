pipeline {
  agent any

  environment {
    IMAGE_NAME = "chamaray/numeric-app"
  }

  stages {

    // =========================
    // Build & Unit Test
    // =========================
    stage('Build & Unit Test') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        sh "mvn clean verify"
        stash includes: 'target/*.jar', name: 'app-jar'
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

    // =========================
    // SonarQube Analysis
    // =========================
    stage('SonarQube - SAST') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        withSonarQubeEnv('SonarQube') {
          sh """
          mvn sonar:sonar \
          -Dsonar.projectKey=numeric-application \
          -Dsonar.projectName=numeric-application
          """
        }
      }
    }

    // =========================
    // Quality Gate
    // =========================
    stage('Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    // =========================
    // Vulnerability Scans (Parallel)
    // =========================
    stage('Vulnerability Scan') {
  parallel {

    stage('Dependency Scan') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        sh "mvn dependency-check:check"
      }
      post {
        always {
          dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
        }
      }
    }

    stage('OPA Conftest') {
      steps {
        sh """
        docker run --rm \
          -v \$(pwd):/project \
          openpolicyagent/conftest test \
          --policy opa-docker-security.rego \
          Dockerfile \
          --all-namespaces
        """
      }
    }

  }
}

        // Trivy Docker Image Scan
        stage('Trivy Scan') {
          steps {
            sh """
            docker run --rm \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -v ~/.cache:/root/.cache \
              aquasec/trivy:0.50.0 \
              image --severity HIGH,CRITICAL \
              --exit-code 1 \
              ${IMAGE_NAME}:${GIT_COMMIT} || true
            """
          }
        }
      }
    }

    // =========================
    // Mutation Testing
    // =========================
    stage('Mutation Testing (PIT)') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        sh "mvn org.pitest:pitest-maven:mutationCoverage"
      }
      post {
        always {
          archiveArtifacts artifacts: 'target/pit-reports/**', fingerprint: true
        }
      }
    }

    // =========================
    // Archive Artifact
    // =========================
    stage('Archive Artifact') {
      steps {
        unstash 'app-jar'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    // =========================
    // Docker Build & Push
    // =========================
    stage('Docker Build & Push') {
      steps {
        unstash 'app-jar'
        withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
          sh """
          docker build -t ${IMAGE_NAME}:${GIT_COMMIT} .
          docker push ${IMAGE_NAME}:${GIT_COMMIT}
          """
        }
      }
    }

    // =========================
    // Deploy to Kubernetes
    // =========================
    stage('Deploy to Kubernetes') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig']) {
          sh """
          sed -i 's#replace#${IMAGE_NAME}:${GIT_COMMIT}#g' k8s_deployment_service.yaml
          kubectl apply -f k8s_deployment_service.yaml
          """
        }
      }
    }
  }

  // =========================
  // Post Actions
  // =========================
  post {
    success {
      echo "✅ Pipeline executed successfully!"
    }
    failure {
      echo "❌ Pipeline failed. Check logs."
    }
  }
}
