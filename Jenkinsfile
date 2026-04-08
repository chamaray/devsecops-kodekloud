pipeline {
  agent any

  environment {
    IMAGE_NAME = "chamaray/numeric-app"
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
      }
      post {
        always {
          junit 'target/surefire-reports/*.xml'
          jacoco execPattern: 'target/jacoco.exec'
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
          pitmutation mutationStatsFile: '**/target/pit-reports/mutations.xml'
        }
      }
    }

    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
      }
    }

    stage('Docker Build & Push') {
      steps {
        withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
          sh """
          docker build -t ${IMAGE_NAME}:${GIT_COMMIT} .
          docker push ${IMAGE_NAME}:${GIT_COMMIT}
          """
        }
      }
    }

    stage('Kubernetes Deployment - DEV') {
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
    success {
      echo "✅ Pipeline executed successfully!"
    }
    failure {
      echo "❌ Pipeline failed. Check logs."
    }
  }
}
