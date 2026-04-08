pipeline {
  agent any

  tools {
    maven 'maven3'
  }

  stages {

    stage('Checkout') {
      steps {
        git 'https://github.com/chamaray/devsecops-kodekloud'
      }
    }

    stage('Build & Unit Test') {
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

          sh "docker build -t chamaray/numeric-app:${GIT_COMMIT} ."
          sh "docker push chamaray/numeric-app:${GIT_COMMIT}"

        }
      }
    }

    stage('Kubernetes Deployment - DEV') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig']) {

          sh """
          sed -i 's#replace#chamaray/numeric-app:${GIT_COMMIT}#g' k8s_deployment_service.yaml
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
