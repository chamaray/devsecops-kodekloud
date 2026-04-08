pipeline {
  agent any

  environment {
    IMAGE_NAME = "chamaray/numeric-app"
    SONAR_HOST_URL = "http://51.142.180.96:9000"
  }

  stages {

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
          junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
        }
      }
    }

    stage('SonarQube - SAST') {
      agent {
        docker {
          image 'maven:3.9.6-eclipse-temurin-17'
        }
      }
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh """
          mvn sonar:sonar \
          -Dsonar.projectKey=numeric-appication \
          -Dsonar.projectName=numeric-appication \
          -Dsonar.host.url=http://51.142.180.96:9000 \
          -Dsonar.login=sqp_031a335c5213322dc2f33f3cbd0025b612df7a38
          """
        }
      }
    }

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
          script {
            try {
              pitmutation mutationStatsFile: 'target/pit-reports/**/mutations.xml'
            } catch (Exception e) {
              echo "Pit mutation reports not found, skipping..."
            }
          }
        }
      }
    }

    stage('Archive Artifact') {
      steps {
        unstash 'app-jar'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

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

  post {
    success { echo "✅ Pipeline executed successfully!" }
    failure { echo "❌ Pipeline failed. Check logs." }
  }
}
